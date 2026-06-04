# Proxy Text-to-Speech : transmet le texte à l'API Kokoro-82M via OpenRouter
# et renvoie le fichier audio MP3 au navigateur.
# La clé API reste côté serveur (jamais exposée au client).
class TtsController < ApplicationController
  MAX_TEXT_LENGTH = 4000
  DEFAULT_VOICE = "ff_siwis"

  def speak
    text = params[:text].to_s.strip

    return head :bad_request if text.blank?
    return head :bad_request if text.length > MAX_TEXT_LENGTH

    voice = params[:voice] || DEFAULT_VOICE

    uri = URI("#{ENV.fetch('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1')}/audio/speech")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: "hexgrad/kokoro-82m",
      input: text,
      voice: voice,
      response_format: "mp3"
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      send_data response.body,
        type: "audio/mpeg",
        disposition: "inline"
    else
      Rails.logger.error "TTS failed: #{response.code} — #{response.body.truncate(200)}"
      head :unprocessable_entity
    end
  end
end
