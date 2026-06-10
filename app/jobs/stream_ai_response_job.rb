# Stream la reponse d'IA token-par-token via OpenRouter SSE, puis broadcast
# chaque batch via Turbo::StreamsChannel (le channel officiel souscrit par
# turbo_stream_from @conversation) en Turbo Stream (replace du message
# assistant) pour affichage progressif.
#
# Batch : on accumule les tokens pendant FLUSH_INTERVAL_MS puis on UPDATE le
# message en DB et on broadcast le Turbo Stream. Evite N updates pour N tokens.
class StreamAiResponseJob < ApplicationJob
  queue_as :default

  FLUSH_INTERVAL_MS = 20
  FLUSH_SIZE        = 6

  def perform(message_id)
    @message = Message.find(message_id)
    @message.update!(streaming: true)
    @message.reload
    broadcast_replace

    parent_msg = parent_user_message
    unless parent_msg
      Rails.logger.error "StreamAiResponseJob: aucun message user precedent pour AI message #{@message.id}"
      @message.update!(streaming: false,
                       content: @message.content.presence || "Desole, une erreur est survenue.")
      @message.reload
      broadcast_replace
      return
    end

    @buffer     = +""
    @last_flush = Time.current

    OpenRouterService.new(@message.conversation, parent_msg).call_streaming do |token|
      accumulate_and_flush(token)
    end

    flush_buffer(@buffer) unless @buffer.empty?
    @message.reload

    @message.update!(streaming: false)
    @message.reload
    broadcast_replace
  rescue StandardError => e
    Rails.logger.error "StreamAiResponseJob error: #{e.class} — #{e.message}"
    @message&.update!(
      streaming: false,
      content: @message.content.presence || "Desole, une erreur est survenue. Reessaie."
    )
    @message&.reload
    broadcast_replace if @message
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
    Time.current - @last_flush >= FLUSH_INTERVAL_MS / 1000.0 ||
      @buffer.length >= FLUSH_SIZE ||
      @buffer.match?(/[\s.,!?;:\n]$/)
  end

  def flush_buffer(buffer)
    return if buffer.empty?

    new_content = @message.content.to_s + buffer.dup
    @message.update_columns(content: new_content, updated_at: Time.current)
    @message.reload
    broadcast_replace
    buffer.clear
  end

  def broadcast_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      @message.conversation,
      target: ActionView::RecordIdentifier.dom_id(@message),
      partial: "messages/message",
      locals: { message: @message }
    )
    Rails.logger.warn "[StreamAi] Replace OK msg=#{@message.id} content=#{@message.content.to_s.truncate(40)}"
  rescue StandardError => e
    Rails.logger.error "[StreamAi] Replace FAILED msg=#{@message.id}: #{e.message}"
  end
end
