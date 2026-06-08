require "test_helper"

class StreamAiResponseJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
    @conversation = @user.conversations.create!(name: "Stream test")
    @user_message = @conversation.messages.create!(role: "user", content: "Bonjour IA")
    @ai_message = @conversation.messages.create!(role: "assistant", content: "", streaming: true)
    @original_call_streaming = OpenRouterService.instance_method(:call_streaming)
  end

  teardown do
    OpenRouterService.define_method(:call_streaming, @original_call_streaming)
    restore_broadcast_replace
  end

  test "remplit le contenu et broadcast_replace a chaque batch" do
    stub_call_streaming("Bonjour ! Comment ça va ?")
    broadcasts = []
    stub_broadcast_replace(broadcasts)

    StreamAiResponseJob.perform_now(@ai_message.id)

    assert_equal "Bonjour ! Comment ça va ?", @ai_message.reload.content
    assert_equal false, @ai_message.streaming
    assert broadcasts.size >= 1, "Au moins un broadcast_replace doit etre envoye"
  end

  test "gere une exception API en mettant un message d'erreur" do
    OpenRouterService.define_method(:call_streaming) { |&_block| raise StandardError, "API down" }
    broadcasts = []
    stub_broadcast_replace(broadcasts)

    begin
      StreamAiResponseJob.perform_now(@ai_message.id)
    rescue StandardError
      # ignore (retry_on de ApplicationJob peut le laisser sortir)
    end

    assert_equal false, @ai_message.reload.streaming
    assert_match(/erreur/i, @ai_message.content.to_s)
  end

  test "est dans la queue default" do
    assert_equal "default", StreamAiResponseJob.new.queue_name
  end

  private

  def stub_call_streaming(content)
    tokens = content.chars
    OpenRouterService.define_method(:call_streaming) do |&block|
      tokens.each { |t| block.call(t) }
      content
    end
  end

  # Stub Turbo::StreamsChannel.broadcast_replace_to pour capturer les
  # broadcasts sans toucher au serveur ActionCable.
  def stub_broadcast_replace(captured)
    @original_broadcast_replace = Turbo::StreamsChannel.method(:broadcast_replace_to)
    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |*streamables, **opts|
      captured << [streamables, opts]
    end
  end

  def restore_broadcast_replace
    if @original_broadcast_replace
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, @original_broadcast_replace)
    end
  end
end
