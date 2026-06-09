class LlmCallService
  API_URL = "https://openrouter.ai/api/v1/chat/completions"

  FALLBACK_MODELS = [
    "deepseek/deepseek-v4-flash",
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "google/gemma-4-26b-a4b-it:free"
  ].freeze

  # ——— Synchrone ———

  def self.oneshot(prompt, model: nil) # rubocop:disable Metrics/MethodLength
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

  # ——— Streaming SSE — yield chaque token au bloc ———

  def self.stream(prompt, model: nil, &block) # rubocop:disable Metrics/MethodLength
    models = [model, *FALLBACK_MODELS].compact.uniq
    uri    = URI(API_URL)

    models.each do |m|
      yielded = false
      Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                          open_timeout: 10, read_timeout: 60) do |http|
        http.request(build_stream_request(uri, m, prompt)) do |resp|
          next unless resp.code.to_i == 200

          resp.read_body do |chunk|
            chunk.each_line do |line|
              token = parse_sse_token(line)
              next unless token.is_a?(String)

              block.call(token)
              yielded = true
            end
          end
        end
      end
      return if yielded
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
           Errno::ECONNRESET, SocketError => e
      Rails.logger.error "LlmCallService stream error for #{m}: #{e.message}"
    end
  end

  # ——— Helpers privés ———

  def self.post(model, prompt) # rubocop:disable Metrics/MethodLength
    Faraday.post(API_URL) do |req|
      req.options.timeout = 30
      req.options.open_timeout = 10
      req.headers["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
      req.headers["Content-Type"]  = "application/json"
      req.headers["HTTP-Referer"]  = "https://mindsnap.app"
      req.headers["X-Title"]       = "MindSnap"
      req.body = JSON.generate(model: model,
                               messages: [{ role: "user", content: prompt }])
    end
  rescue Faraday::Error => e
    Rails.logger.error "LlmCallService Faraday error for #{model}: #{e.message}"
    nil
  end

  def self.build_stream_request(uri, model, prompt)
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
    req["Content-Type"]  = "application/json"
    req["Accept"]        = "text/event-stream"
    req["HTTP-Referer"]  = "https://mindsnap.app"
    req["X-Title"]       = "MindSnap"
    req.body = JSON.generate(model: model,
                             messages: [{ role: "user", content: prompt }],
                             stream: true)
    req
  end

  def self.parse_sse_token(line)
    line = line.chomp
    return nil if line.empty? || line.start_with?(":")
    return nil unless line.start_with?("data:")

    data = line.sub(/^data:\s*/, "").strip
    return nil if data == "[DONE]"

    payload = JSON.parse(data)
    delta   = payload.dig("choices", 0, "delta", "content")
    delta.is_a?(String) && delta.present? ? delta : nil
  rescue JSON::ParserError
    nil
  end

  private_class_method :post, :build_stream_request, :parse_sse_token
end
