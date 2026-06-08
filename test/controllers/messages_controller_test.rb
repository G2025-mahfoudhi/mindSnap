require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    @conversation = @user.conversations.create!(name: "Test messages")
  end

  test "redirige vers login si pas connecté" do
    post conversation_messages_path(@conversation), params: { message: { content: "Hello" } }
    assert_redirected_to new_user_session_path
  end

  test "create message en HTML" do
    sign_in @user
    post conversation_messages_path(@conversation), params: { message: { content: "Bonjour" } }
    assert_redirected_to conversation_path(@conversation)
    assert_equal 2, @conversation.messages.count
    assert_equal "user", @conversation.messages.first.role
    assert_equal "assistant", @conversation.messages.last.role
  end

  test "create message en turbo_stream" do
    sign_in @user
    post conversation_messages_path(@conversation),
         params: { message: { content: "Hello" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "streaming : cree un ai_message vide, flag streaming=true, enqueue le job" do
    sign_in @user
    assert_enqueued_with(job: StreamAiResponseJob) do
      post conversation_messages_path(@conversation),
           params: { message: { content: "Salut IA" } }
    end

    user_msg = @conversation.messages.find_by(role: "user", content: "Salut IA")
    ai_msg   = @conversation.messages.find_by(role: "assistant")
    assert_not_nil user_msg
    assert_not_nil ai_msg
    assert_equal "", ai_msg.content
    assert_equal true, ai_msg.streaming
  end
end
