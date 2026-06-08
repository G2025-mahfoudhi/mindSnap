# Service de chat IA via OpenRouter (Faraday HTTP).
# Gère l'historique de conversation, le fallback multi-modèles,
# et enrichit le prompt système avec le contexte RAG (Phase 2).
#
# Flux : call → build_rag_context (pgvector search) → system_prompt enrichi
#        → modèle principal → fallback si rate-limit → réponse
class OpenRouterService
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

  def system_prompt
    user     = @conversation.user
    all_docs = user.documents.includes(:folder).order(:created_at)
    doc_list = all_docs.map { |d| format_doc_entry(d) }.join("\n")

    focused_doc_section = focused_document_section

    <<~PROMPT.strip
      Tu es MindSnap, un assistant de gestion de connaissances personnelles.
      Tu aides l'utilisateur à retrouver, comprendre et connecter ses documents.
      #{focused_doc_section}
      ## Inventaire complet (#{all_docs.size} document#{'s' if all_docs.size > 1})
      #{doc_list.presence || "Aucun document dans l'espace."}

      ## Contenu pertinent pour cette question
      #{@rag_context.presence || 'Aucun contenu pertinent trouvé pour cette question.'}

      ## Règles
      1. #{focused_doc_section.present? ? "Tu es en mode discussion sur un document précis — concentre-toi d'abord sur ce document." : "Tu connais TOUS les documents listés dans l'inventaire."}
      2. Si du contenu pertinent est fourni → base ta réponse dessus. Cite le titre : *(source: Titre)*.
      3. Si aucun contenu pertinent → dis "Je n'ai pas le contenu de ce document, mais voici ce que je sais :" puis réponds avec tes connaissances générales.
      4. Sois concis, structuré, réponds dans la langue de la question.
      5. Réponds naturellement à tous les messages, y compris les salutations.
    PROMPT
  end

  def focused_document_section
    return "" unless @conversation.context_type == "Document" && @conversation.context_id.present?

    doc = Document.find_by(id: @conversation.context_id)
    return "" unless doc

    info = doc.summary.present? ? "Résumé : #{doc.summary.truncate(400)}" : doc.content.to_s.truncate(600)
    <<~SECTION

      ## Document en cours de discussion
      Titre : #{doc.title}
      Type : #{doc.document_type}
      #{info}

    SECTION
  end

  def format_doc_entry(doc)
    folder_info  = doc.folder ? " (dossier: #{doc.folder.name})" : ""
    summary_info = doc.summary.present? ? "\n  Résumé : #{doc.summary.truncate(200)}" : ""
    content_info = doc.content.present? && doc.summary.blank? ? "\n  Contenu : #{doc.content.truncate(300)}" : ""
    "- #{doc.title} [#{doc.document_type}]#{folder_info}#{summary_info}#{content_info}"
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
