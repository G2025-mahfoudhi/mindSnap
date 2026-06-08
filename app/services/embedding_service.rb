class EmbeddingService
  API_URL = "https://openrouter.ai/api/v1/embeddings"
  EMBEDDING_DIMENSIONS = 1024

  EMBEDDING_MODELS = [
    "qwen/qwen3-embedding-8b",
    "intfloat/e5-mistral-7b-instruct"
  ].freeze

  def self.embed(text)
    EMBEDDING_MODELS.each do |model|
      response = post(model, text)
      next unless response

      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
        Rails.logger.error "EmbeddingService: réponse non-JSON de #{model}"
        next
      end

      if body["error"]
        Rails.logger.warn "EmbeddingService: #{model} error — #{body['error']['message']}"
        next
      end

      full_embedding = body.dig("data", 0, "embedding")
      next unless full_embedding

      return full_embedding.first(EMBEDDING_DIMENSIONS)
    end

    Rails.logger.error "EmbeddingService: tous les modèles ont échoué"
    nil
  end

  def self.post(model, text)
    Faraday.post(API_URL) do |req|
      req.options.timeout = 30
      req.options.open_timeout = 10
      req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      req.headers["Content-Type"]  = "application/json"
      req.headers["HTTP-Referer"]  = "https://mindsnap.app"
      req.headers["X-Title"]       = "MindSnap"
      req.body = JSON.generate({ model: model, input: text })
    end
  rescue Faraday::Error => e
    Rails.logger.error "EmbeddingService network error for #{model}: #{e.message}"
    nil
  end
end
