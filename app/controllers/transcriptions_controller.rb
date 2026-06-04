# Proxy Speech-to-Text : reçoit l'audio en base64 depuis le navigateur,
# le transmet à l'API Whisper via OpenRouter, et renvoie la transcription texte.
# La clé API reste côté serveur (jamais exposée au client).
class TranscriptionsController < ApplicationController
  MAX_AUDIO_SIZE = 10 * 1024 * 1024 # 10 MB

  def create
    audio_base64 = params[:audio_base64]
    format = params[:format] || "webm"
    language = params[:language] || "fr"

    return head :bad_request if audio_base64.blank?

    estimated_size = (audio_base64.length * 3) / 4
    return head :payload_too_large if estimated_size > MAX_AUDIO_SIZE

    uri = URI("#{ENV.fetch('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1')}/audio/transcriptions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENROUTER_API_KEY']}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: "openai/whisper-large-v3-turbo",
      input_audio: {
        data: audio_base64,
        format: format
      },
      language: language
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      render json: JSON.parse(response.body)
    else
      Rails.logger.error "Transcription failed: #{response.code} — #{response.body.truncate(200)}"
      render json: { error: "Transcription failed" }, status: :unprocessable_entity
    end
  end
end
