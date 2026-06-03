class OpenRouterService
  API_URL = "https://openrouter.ai/api/v1/chat/completions"

  # Fallback ordonné : si le premier est rate-limité, on essaie le suivant
  FALLBACK_MODELS = [
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "poolside/laguna-xs.2:free",
    "google/gemma-4-26b-a4b-it:free"
  ].freeze

  def initialize(conversation, user_message)
    @conversation = conversation
    @user_message = user_message
  end

  def call
    models_to_try.each do |model|
      response = post(model)
      parsed   = JSON.parse(response.body)
      content  = parsed.dig("choices", 0, "message", "content").presence

      return content if content

      Rails.logger.warn "OpenRouter: #{model} a échoué (#{response.status}) — #{parsed.dig('error', 'message')}"
    end

    raise "Tous les modèles ont échoué"
  end

  private

  def models_to_try
    configured = ENV["OPENROUTER_MODEL"].presence
    configured ? [ configured, *FALLBACK_MODELS ].uniq : FALLBACK_MODELS
  end

  def post(model)
    Faraday.post(API_URL) do |req|
      req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      req.headers["Content-Type"]  = "application/json"
      req.headers["HTTP-Referer"]  = "https://mindsnap.app"
      req.headers["X-Title"]       = "MindSnap"
      req.body = JSON.generate({ model: model, messages: messages_for_api })
    end
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
      Tu es un assistant intelligent intégré à MindSnap, une application de gestion de connaissances personnelles.
      MindSnap permet de stocker et d'organiser les documents, idéé, note, d'extaire un contenu à partir d'url et d'analyser les contenus.
      Tu as accès à ma base de donnée documentaire vectorielle (PostgreSQL + pgvector) qui contient les documents et notes de l'utilisateur et à mon espace dans espaces#index.
      Ton rôle est de répondre aux questions de l'utilisateur en t'appuyant prioritairement sur les documents retrouvés par recherche vectorielle sémantique.
      Si on te demande le chemin d'accès, écris le à partir de espaces.

      Comportement attendu :
      - Réponds naturellement à tous les messages, y compris les salutations, questions vagues ou hors-sujet.
      - Sois chaleureux et concis.
      - À la fin de chaque réponse, ramène toujours la conversation vers les documents de l'utilisateur.

      Par exemple : propose d'explorer un document, de répondre à une question sur ses notes, ou de l'aider à organiser ses connaissances.
      - Ne force pas le lien si la question est déjà liée aux documents.
      - Réponds toujours en te basant sur les documents pertinents fournis en contexte.
      - Si un document répond directement à la question, cite son contenu de façon précise.
      - Si aucun document pertinent n'est disponible, dis-le clairement avant de répondre avec tes connaissances générales.
      - Ne confonds jamais tes connaissances générales avec le contenu des documents de l'utilisateur.
      - Reste concis, structuré, et utile.
      - Utilise la même langue que l'utilisateur.
    PROMPT
  end
end
