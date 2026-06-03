# Utilitaire pour des appels LLM ponctuels (one-shot), sans historique.
# Utilisé par SummarizeDocumentJob et TagDocumentJob qui n'ont pas besoin
# du contexte de conversation.
class LlmCallService
  def self.oneshot(prompt, model: ENV.fetch("OPENROUTER_MODEL", "nvidia/nemotron-3-super-120b-a12b:free"))
    uri = URI("#{ENV.fetch('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1')}/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: model,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    body = JSON.parse(response.body)

    if body["error"]
      Rails.logger.error "LlmCallService error: #{body["error"]["message"]}"
      return nil
    end

    body.dig("choices", 0, "message", "content")
  end
end
