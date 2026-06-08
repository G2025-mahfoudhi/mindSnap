# Stream la reponse d'IA token-par-token via OpenRouter SSE, puis broadcast
# chaque batch via ActionCable (channel conversation_#{id}) en Turbo Stream
# (replace du message assistant) pour affichage progressif.
#
# Batch : on accumule les tokens pendant FLUSH_INTERVAL_MS puis on UPDATE le
# message en DB et on broadcast le Turbo Stream. Evite N updates pour N tokens.
class StreamAiResponseJob < ApplicationJob
  queue_as :default

  FLUSH_INTERVAL_MS = 50
  FLUSH_MIN_TOKENS  = 4

  def perform(message_id) # rubocop:disable Metrics/MethodLength
    @message = Message.find(message_id)
    @message.update!(streaming: true)
    broadcast_message

    @buffer     = +""
    @last_flush = Time.current

    OpenRouterService.new(@message.conversation, parent_user_message).call_streaming do |token|
      accumulate_and_flush(token)
    end

    flush_buffer(@buffer) unless @buffer.empty?

    @message.update!(streaming: false)
    broadcast_message
  rescue StandardError => e
    Rails.logger.error "StreamAiResponseJob error: #{e.class} — #{e.message}"
    @message&.update!(
      streaming: false,
      content: @message.content.presence || "Désolé, une erreur est survenue. Réessaie."
    )
    broadcast_message if @message
    raise
  end

  private

  def parent_user_message
    @message.conversation.messages
            .where(role: "user")
            .where("created_at < ?", @message.created_at)
            .order(created_at: :desc)
            .first
  end

  def accumulate_and_flush(token)
    @buffer << token
    return unless should_flush?

    flush_buffer(@buffer)
    @last_flush = Time.current
  end

  def should_flush?
    Time.current - @last_flush >= FLUSH_INTERVAL_MS / 1000.0 || @buffer.length >= 80
  end

  def flush_buffer(buffer)
    return if buffer.empty?

    new_content = @message.content.to_s + buffer.dup
    @message.update_columns(content: new_content, updated_at: Time.current)
    buffer.clear
    broadcast_message
  end

  # Envoie un Turbo Stream (replace du message) via ActionCable.
  def broadcast_message # rubocop:disable Metrics/MethodLength
    html = ApplicationController.render(
      partial: "messages/message",
      locals: { message: @message },
      layout: false
    )

    turbo_stream = <<~TURBO
      <turbo-stream action="replace" target="message_#{@message.id}">
        <template>#{html}</template>
      </turbo-stream>
    TURBO

    ActionCable.server.broadcast(
      "conversation_#{@message.conversation_id}",
      { html: turbo_stream }
    )
  end
end
