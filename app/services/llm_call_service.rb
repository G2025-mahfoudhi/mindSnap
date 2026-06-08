class LlmCallService
  API_URL = "https://openrouter.ai/api/v1/chat/completions"

  FALLBACK_MODELS = [
    "deepseek/deepseek-v4-flash",
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "google/gemma-4-26b-a4b-it:free"
  ].freeze

  def self.oneshot(prompt, model: nil)
    models = [model, *FALLBACK_MODELS].compact.uniq

    models.each do |m|
      response = post(m, prompt)
      next unless response&.body

      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
        Rails.logger.error "LlmCallService: réponse non-JSON de #{m}"
        next
      end
      content = body.dig("choices", 0, "message", "content").presence
      return content if content

      Rails.logger.warn "LlmCallService: #{m} a échoué (#{response.status}) — #{body.dig('error', 'message')}"
    end

    Rails.logger.error "LlmCallService: tous les modèles ont échoué"
    nil
  end

  def self.post(model, prompt)
    Faraday.post(API_URL) do |req|
      req.options.timeout = 30
      req.options.open_timeout = 10
      req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      req.headers["Content-Type"]  = "application/json"
      req.headers["HTTP-Referer"]  = "https://mindsnap.app"
      req.headers["X-Title"]       = "MindSnap"
      req.body = JSON.generate({
                                 model: model,
                                 messages: [{ role: "user", content: prompt }]
                               })
    end
  rescue Faraday::Error => e
    Rails.logger.error "LlmCallService Faraday error for #{model}: #{e.message}"
    nil
  end
end
