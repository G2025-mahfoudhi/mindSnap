# Appelle l'API OpenRouter pour générer un embedding vectoriel via qwen3-embedding-8b.
# Le modèle produit des vecteurs 4096-dim que l'on tronque à 1024 dimensions
# via Matryoshka Representation Learning (MRL). Les 1024 premières dimensions
# contiennent l'essentiel de l'information sémantique.
# Limite HNSW pgvector = 2000 dimensions → 1024 est compatible.
class EmbeddingService
  EMBEDDING_DIMENSIONS = 1024
  EMBEDDING_MODEL = "qwen/qwen3-embedding-8b"

  def self.embed(text)
    uri = URI("#{ENV.fetch('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1')}/embeddings")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: EMBEDDING_MODEL,
      input: text
    }.to_json

    response = http.request(request)
    body = JSON.parse(response.body)

    if body["error"]
      Rails.logger.error "EmbeddingService error: #{body["error"]["message"]}"
      return nil
    end

    full_embedding = body.dig("data", 0, "embedding")
    return nil unless full_embedding

    # Troncature MRL : on garde les 1024 premières dimensions
    full_embedding.first(EMBEDDING_DIMENSIONS)
  end
end
