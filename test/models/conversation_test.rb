require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "conversation valide avec nom et user" do
    conversation = Conversation.new(name: "Test conv", user: @user)
    assert conversation.valid?
  end

  test "invalide sans nom" do
    conversation = Conversation.new(user: @user)
    assert_not conversation.valid?
  end

  test "peut avoir un contexte polymorphic (Folder)" do
    folder = Folder.create!(name: "Test folder", user: @user)
    conversation = Conversation.create!(
      name: "Chat dossier",
      user: @user,
      context: folder
    )
    assert_equal "Folder", conversation.context_type
    assert_equal folder.id, conversation.context_id
    assert_equal folder, conversation.context
  end

  test "folder_scoped? retourne true si contexte Folder" do
    folder = Folder.create!(name: "ML docs", user: @user)
    conversation = Conversation.create!(
      name: "Chat ML",
      user: @user,
      context: folder
    )
    assert conversation.folder_scoped?
  end

  test "folder_scoped? retourne false sans contexte" do
    conversation = Conversation.create!(name: "Chat libre", user: @user)
    assert_not conversation.folder_scoped?
  end

  test "contexte optionnel" do
    conversation = Conversation.create!(name: "Sans contexte", user: @user)
    assert_nil conversation.context
    assert_nil conversation.context_type
  end

  test "model par défaut" do
    conversation = Conversation.create!(name: "Default model", user: @user)
    assert_equal "nvidia/nemotron-3-super-120b-a12b:free", conversation.model
  end

  test "a des messages" do
    conversation = Conversation.create!(name: "Messages test", user: @user)
    assert_equal 0, conversation.messages.count
    conversation.messages.create!(role: "user", content: "Hello")
    assert_equal 1, conversation.messages.count
  end
end
