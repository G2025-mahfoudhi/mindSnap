# Stream la reponse d'IA token-par-token via OpenRouter SSE, puis broadcast
# chaque batch via Turbo::StreamsChannel (le channel officiel souscrit par
# turbo_stream_from @conversation) en Turbo Stream (replace du message
# assistant) pour affichage progressif.
#
# Batch : on accumule les tokens pendant FLUSH_INTERVAL_MS puis on UPDATE le
# message en DB et on broadcast le Turbo Stream. Evite N updates pour N tokens.
class StreamAiResponseJob < ApplicationJob
  queue_as :default

  FLUSH_INTERVAL_MS = 50
  FLUSH_MIN_TOKENS  = 4

  def perform(message_id)
    @message = Message.find(message_id)
    @message.update!(streaming: true)
    broadcast_replace

    @buffer     = +""
    @last_flush = Time.current

    OpenRouterService.new(@message.conversation, parent_user_message).call_streaming do |token|
      accumulate_and_flush(token)
    end

    flush_buffer(@buffer) unless @buffer.empty?

    @message.update!(streaming: false)
    broadcast_replace
  rescue StandardError => e
    Rails.logger.error "StreamAiResponseJob error: #{e.class} — #{e.message}"
    @message&.update!(
      streaming: false,
      content: @message.content.presence || "Désolé, une erreur est survenue. Réessaie."
    )
    broadcast_replace if @message
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
    broadcast_replace
  end

  # Broadcast via le channel officiel Turbo (Turbo::StreamsChannel). Les clients
  # abonnes via <%= turbo_stream_from @conversation %> dans la vue recoivent
  # automatiquement le replace du bon element.
  def broadcast_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      @message.conversation,
      target: ActionView::RecordIdentifier.dom_id(@message),
      partial: "messages/message",
      locals: { message: @message }
    )
  end
end
