require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
    @conversation = Conversation.create!(name: "Test conv", user: @user)
  end

  test "valide avec content, role et conversation" do
    message = Message.new(content: "Hello", role: "user", conversation: @conversation)
    assert message.valid?
  end

  test "invalide sans content" do
    message = Message.new(role: "user", conversation: @conversation)
    assert_not message.valid?
  end

  test "invalide sans role" do
    message = Message.new(content: "Hello", conversation: @conversation)
    assert_not message.valid?
  end

  test "appartient à une conversation" do
    message = Message.create!(content: "Test", role: "assistant", conversation: @conversation)
    assert_equal @conversation, message.conversation
  end

  test "le rôle peut être user" do
    message = Message.create!(content: "Hi", role: "user", conversation: @conversation)
    assert_equal "user", message.role
  end

  test "le rôle peut être assistant" do
    message = Message.create!(content: "Hi", role: "assistant", conversation: @conversation)
    assert_equal "assistant", message.role
  end

  test "destroy cascade depuis la conversation" do
    message = @conversation.messages.create!(content: "Test", role: "user")
    @conversation.destroy
    assert_equal 0, Message.where(id: message.id).count
  end
end
