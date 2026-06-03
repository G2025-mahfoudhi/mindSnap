require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  test "redirige vers login si pas connecté" do
    get conversations_path
    assert_redirected_to new_user_session_path
  end

  test "get index" do
    sign_in @user
    get conversations_path
    assert_response :success
  end

  test "create conversation" do
    sign_in @user
    assert_difference("Conversation.count", 1) do
      post conversations_path, params: { conversation: { name: "Test" } }
    end
    assert_redirected_to conversation_path(Conversation.last)
  end

  test "create avec nom vide génère un nom par défaut" do
    sign_in @user
    assert_difference("Conversation.count", 1) do
      post conversations_path, params: { conversation: { name: "" } }
    end
  end

  test "get show" do
    sign_in @user
    conv = @user.conversations.create!(name: "Ma conv")
    get conversation_path(conv)
    assert_response :success
  end

  test "destroy conversation" do
    sign_in @user
    conv = @user.conversations.create!(name: "À supprimer")
    assert_difference("Conversation.count", -1) do
      delete conversation_path(conv)
    end
    assert_redirected_to conversations_path
  end
end
