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
    restore_broadcast
  end

  test "remplit le contenu et broadcast a la fin du stream" do
    stub_call_streaming("Bonjour ! Comment ça va ?")
    broadcasts = []
    stub_broadcast(broadcasts)

    StreamAiResponseJob.perform_now(@ai_message.id)

    assert_equal "Bonjour ! Comment ça va ?", @ai_message.reload.content
    assert_equal false, @ai_message.streaming
    assert broadcasts.size >= 1, "Au moins un broadcast doit etre envoye"
    assert_equal "conversation_#{@conversation.id}", broadcasts.first.first
  end

  test "gere une exception API en mettant un message d'erreur" do
    OpenRouterService.define_method(:call_streaming) { |&_block| raise StandardError, "API down" }
    broadcasts = []
    stub_broadcast(broadcasts)

    # perform_now leve apres les retries de ApplicationJob. Le job doit
    # quand meme avoir mis le message en streaming=false + contenu d'erreur
    # avant de lever.
    begin
      StreamAiResponseJob.perform_now(@ai_message.id)
    rescue StandardError
      # ignore
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

  def stub_broadcast(captured)
    @original_broadcast = ActionCable.server.method(:broadcast)
    ActionCable.server.define_singleton_method(:broadcast) do |stream_name, data|
      captured << [stream_name, data]
    end
  end

  def restore_broadcast
    return unless @original_broadcast

    ActionCable.server.define_singleton_method(:broadcast, @original_broadcast)
  end
end
