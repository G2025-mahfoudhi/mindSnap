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
    <<~PROMPT.strip
      Tu es MindSnap, un assistant de gestion de connaissances personnelles.
      Tu aides l'utilisateur à retrouver, comprendre et connecter ses documents.

      ## Contexte documentaire
      #{@rag_context.presence || "Aucun document pertinent trouvé dans la base de l'utilisateur."}

      ## Règles
      1. Si des documents pertinents sont fournis ci-dessus → base ta réponse dessus. Cite le titre du document comme source : *(source: Titre du doc)*.
      2. Si aucun document pertinent → dis "Je n'ai rien trouvé dans tes documents à ce sujet, mais voici ce que je sais :" puis réponds avec tes connaissances générales.
      3. Ne mélange jamais tes connaissances générales avec le contenu des documents.
      4. Sois concis, structuré, réponds dans la langue de la question.
      5. Si la question ne concerne pas les documents, réponds normalement.
      6. Réponds naturellement à tous les messages, y compris les salutations.
    PROMPT
  end

  # Construit le contexte documentaire via RAG (Phase 2).
  # Cherche dans les chunks vectoriels les plus proches de la question,
  # puis formate le résultat pour l'injection dans le prompt système.
  # Si la conversation est scopée à un dossier, limite la recherche à ce dossier.
  def build_rag_context
    user = @conversation.user
    rag = RagService.new(user)

    folder_id = nil
    folder_id = @conversation.context_id if @conversation.context_type == "Folder" && @conversation.context_id.present?

    chunks = rag.search(@user_message.content, folder_id: folder_id, limit: 5)
    rag.format_context(chunks)
  end
end
