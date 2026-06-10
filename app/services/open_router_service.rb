# Service de chat IA via OpenRouter (Faraday HTTP).
# Gère l'historique de conversation, le fallback multi-modèles,
# et enrichit le prompt système avec le contexte RAG (Phase 2).
#
# Deux modes :
# - call             : synchrone, renvoie la reponse complete (utilise par
#                      le controller doc-chat pour des reponses courtes)
# - call_streaming   : SSE token-par-token, yield chaque chunk via un bloc
#                      (utilise par StreamAiResponseJob pour le streaming)
class OpenRouterService # rubocop:disable Metrics/ClassLength
  API_URL = "https://openrouter.ai/api/v1/chat/completions"

  # Fallback ordonné : si le premier est rate-limité, on essaie le suivant
  FALLBACK_MODELS = [
    "deepseek/deepseek-v4-flash",
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "google/gemma-4-26b-a4b-it:free"
  ].freeze

  def initialize(conversation, user_message)
    @conversation = conversation
    @user_message = user_message
  end

  def call
    @rag_context = build_rag_context

    models_to_try.each do |model|
      response = post(model)
      next unless response&.body

      parsed  = JSON.parse(response.body)
      content = parsed.dig("choices", 0, "message", "content").presence

      return content if content

      Rails.logger.warn "OpenRouter: #{model} a échoué (#{response.status}) — #{parsed.dig('error', 'message')}"
    end

    raise "Tous les modèles ont échoué"
  end

  # Streaming SSE token-par-token avec Net::HTTP (vrai streaming chunked).
  # Yield chaque token (String) au bloc appelant. Renvoie le contenu complet.
  # Utilise stream: true sur l'API OpenRouter, parse les chunks SSE.
  def call_streaming(&block) # rubocop:disable Metrics/MethodLength
    @rag_context = build_rag_context
    accumulated  = +""

    models_to_try.each do |model|
      tokens_yielded = false
      stream_chunks(model) do |token|
        accumulated << token
        block.call(token)
        tokens_yielded = true
      end
      return accumulated if tokens_yielded

      Rails.logger.warn "OpenRouter streaming: #{model} a renvoyé un stream vide"
    rescue Faraday::Error, OpenRouterStreamError => e
      Rails.logger.error "OpenRouter streaming error for #{model}: #{e.class} — #{e.message}"
    end

    raise "Tous les modèles streaming ont échoué"
  end

  # Erreur custom pour le streaming (parse SSE).
  class OpenRouterStreamError < StandardError; end

  private

  def models_to_try
    configured = ENV["OPENROUTER_MODEL"].presence
    configured ? [configured, *FALLBACK_MODELS].uniq : FALLBACK_MODELS
  end

  def post(model)
    Faraday.post(API_URL) do |req|
      req.options.timeout = 30
      req.options.open_timeout = 10
      req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      req.headers["Content-Type"]  = "application/json"
      req.headers["HTTP-Referer"]  = "https://mindsnap.app"
      req.headers["X-Title"]       = "MindSnap"
      req.body = JSON.generate({ model: model, messages: messages_for_api })
    end
  rescue Faraday::Error => e
    Rails.logger.error "OpenRouterService Faraday error for #{model}: #{e.message}"
    nil
  end

  # Appel SSE streaming avec Net::HTTP (vrai streaming chunked, pas Faraday
  # qui charge tout le body en mémoire). Parse les chunks SSE et yield chaque
  # token au bloc appelant.
  def stream_chunks(model, &block) # rubocop:disable Metrics/MethodLength
    uri = URI(API_URL)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                        open_timeout: 10, read_timeout: 60) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      request["Content-Type"]  = "application/json"
      request["Accept"]        = "text/event-stream"
      request["HTTP-Referer"]  = "https://mindsnap.app"
      request["X-Title"]       = "MindSnap"
      request.body = JSON.generate({ model: model, messages: messages_for_api, stream: true })

      http.request(request) do |response|
        unless response.code.to_i == 200
          raise OpenRouterStreamError,
                "HTTP #{response.code} — #{response.body.to_s.truncate(500)}"
        end

        response.read_body do |chunk|
          chunk.each_line do |line|
            case (result = parse_sse_line(line))
            when :done then return
            when nil   then next
            else            block.call(result)
            end
          end
        end
      end
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
         Errno::ECONNRESET, SocketError => e
    raise OpenRouterStreamError, "Network error: #{e.message}"
  end

  # Parse une ligne SSE. Renvoie le token (String), :done, ou nil.
  def parse_sse_line(line)
    line = line.chomp
    return nil if line.empty? || line.start_with?(":")
    return nil unless line.start_with?("data:")

    data = line.sub(/^data:\s*/, "").strip
    return :done if data == "[DONE]"

    payload = JSON.parse(data)
    delta   = payload.dig("choices", 0, "delta", "content")
    delta.is_a?(String) && delta.present? ? delta : nil
  rescue JSON::ParserError
    nil
  end

  def messages_for_api
    [{ role: "system", content: system_prompt }]
      .concat(previous_messages.map { |m| { role: m.role, content: m.content } })
      .append({ role: "user", content: @user_message.content })
  end

  def previous_messages
    @conversation.messages
                 .where(role: %w[user assistant])
                 .where.not(id: @user_message.id)
                 .order(:created_at)
                 .last(18)
  end

  def system_prompt # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity
    user        = @conversation.user
    all_docs    = user.documents.includes(:folder).order(:created_at)
    all_folders = user.folders.includes(:parent).order(:name)
    doc_list    = all_docs.map { |d| format_doc_entry(d) }.join("\n")
    folder_tree = format_folder_tree(all_folders)
    user_name   = user.first_name.presence || user.email.split("@").first

    focused_doc_section = focused_document_section
    lang_instruction = language_instruction(user)

    <<~PROMPT.strip
      Tu es MindSnap, un assistant de gestion de connaissances personnelles intelligent et bienveillant.
      Tu aides #{user_name} à retrouver, comprendre, relier et approfondir ses documents.
      Tu es précis, pédagogue et proactif — tu transformes des notes éparses en connaissances structurées et exploitables.
      #{focused_doc_section}
      ## Inventaire complet (#{all_docs.size} document#{'s' if all_docs.size > 1})
      #{doc_list.presence || "Aucun document dans l'espace."}

      ## Dossiers disponibles (#{all_folders.size} dossier#{'s' if all_folders.size > 1})
      #{folder_tree.presence || 'Aucun dossier créé.'}

      ## Contenu pertinent pour cette question
      #{@rag_context.presence || 'Aucun contenu pertinent trouvé pour cette question.'}

      ## Règles
      1. #{focused_doc_section.present? ? "Tu es en mode discussion sur un document précis — concentre-toi d'abord sur ce document." : "Tu connais TOUS les documents listés dans l'inventaire."}
      2. Si du contenu pertinent est fourni → base ta réponse dessus. Cite le titre : *(source: Titre)*.
      3. Si aucun contenu pertinent → dis "Je n'ai pas le contenu de ce document, mais voici ce que je sais :" puis réponds avec tes connaissances générales.
      4. #{lang_instruction}
      5. Réponds naturellement à tous les messages, y compris les salutations.
      6. Quand plusieurs documents sont pertinents, fais des connexions explicites entre eux et propose une synthèse globale avant de détailler par source.
      7. Utilise le Markdown pour structurer tes réponses (titres `##`, listes `-`, **gras**) dès que cela améliore la lisibilité.
      8. Si une question est ambiguë, reformule ta compréhension en une phrase avant de répondre.
      9. En fin de réponse complexe, propose 1 à 2 questions de suivi pertinentes pour approfondir le sujet.
      10. Si un document discuté n'a pas encore de dossier et que des dossiers sont disponibles, suggère en fin de réponse le dossier le plus pertinent parmi ceux listés ci-dessus (format exact : 📁 *Dossier suggéré : NomDossier*).
    PROMPT
  end

  def focused_document_section # rubocop:disable Metrics/MethodLength
    return "" unless @conversation.context_type == "Document" && @conversation.context_id.present?

    doc = Document.find_by(id: @conversation.context_id)
    return "" unless doc

    parts = []
    parts << "Résumé :\n#{doc.summary}" if doc.summary.present?
    parts << "Contenu intégral :\n#{doc.content.truncate(6_000)}" if doc.content.present?
    body = parts.join("\n\n").presence || "(contenu non encore extrait)"

    <<~SECTION

      ## Document en cours de discussion — PRIORITÉ ABSOLUE
      Titre : #{doc.title}
      Type  : #{doc.document_type}
      #{body}

    SECTION
  end

  def format_doc_entry(doc)
    folder_info  = doc.folder ? " (dossier: #{doc.folder.name})" : ""
    summary_info = doc.summary.present? ? "\n  Résumé : #{doc.summary.truncate(200)}" : ""
    content_info = doc.content.present? && doc.summary.blank? ? "\n  Contenu : #{doc.content.truncate(300)}" : ""
    "- #{doc.title} [#{doc.document_type}]#{folder_info}#{summary_info}#{content_info}"
  end

  def language_instruction(user)
    case user.preferred_language
    when "en"
      "Always respond in English, regardless of the question's language."
    else
      "Réponds toujours en français, quelle que soit la langue de la question."
    end
  end

  def format_folder_tree(folders)
    folders.map do |f|
      f.parent ? "  └─ #{f.name} (dans #{f.parent.name})" : "- #{f.name}"
    end.join("\n")
  end

  # Construit le contexte documentaire via RAG (Phase 2).
  # Cherche dans les chunks vectoriels les plus proches de la question,
  # puis formate le résultat pour l'injection dans le prompt système.
  # Si la conversation est scopée à un dossier, limite la recherche à ce dossier.
  def build_rag_context
    rag         = RagService.new(@conversation.user)
    document_id = @conversation.context_id if @conversation.context_type == "Document"
    folder_id   = @conversation.context_id if @conversation.context_type == "Folder"

    chunks  = rag.search(@user_message.content, folder_id: folder_id, document_id: document_id, limit: 6)
    context = rag.format_context(chunks)

    context.presence || fallback_context(@conversation.user, folder_id: folder_id, document_id: document_id)
  end

  def fallback_context(user, folder_id: nil, document_id: nil)
    scope = user.documents.where.not(content: [nil, ""])
    scope = scope.where(id: document_id)      if document_id
    scope = scope.where(folder_id: folder_id) if folder_id && !document_id

    docs = scope.limit(10)
    return nil if docs.empty?

    docs.map do |doc|
      "[Document: \"#{doc.title}\" — Type: #{doc.document_type}]\n#{doc.content.truncate(1500)}"
    end.join("\n\n")
  end
end
