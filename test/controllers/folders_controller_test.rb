require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  test "redirige vers login si pas connecté" do
    get folders_path
    assert_redirected_to new_user_session_path
  end

  test "get index" do
    sign_in @user
    get folders_path
    assert_response :success
  end

  test "get new" do
    sign_in @user
    get new_folder_path
    assert_response :success
  end

  test "create folder" do
    sign_in @user
    assert_difference("Folder.count", 1) do
      post folders_path, params: {
        folder: { name: "Nouveau dossier", description: "Desc" }
      }
    end
    assert_response :redirect
  end

  test "get show" do
    sign_in @user
    folder = Folder.create!(name: "Show test", user: @user)
    get folder_path(folder)
    assert_response :success
  end

  test "get edit" do
    sign_in @user
    folder = Folder.create!(name: "Edit test", user: @user)
    get edit_folder_path(folder)
    assert_response :success
  end

  test "update folder" do
    sign_in @user
    folder = Folder.create!(name: "Old name", user: @user)
    patch folder_path(folder), params: { folder: { name: "New name" } }
    assert_redirected_to folder_path(folder)
    assert_equal "New name", folder.reload.name
  end

  test "destroy folder" do
    sign_in @user
    folder = Folder.create!(name: "Destroy test", user: @user)
    assert_difference("Folder.count", -1) do
      delete folder_path(folder)
    end
    assert_redirected_to espaces_path
  end

  test "chat crée une conversation scopée" do
    sign_in @user
    folder = Folder.create!(name: "Chat folder", user: @user)
    assert_difference("Conversation.count", 1) do
      post chat_folder_path(folder)
    end
    conv = Conversation.last
    assert_equal "Folder", conv.context_type
    assert_equal folder.id, conv.context_id
    assert_redirected_to conversation_path(conv)
  end

  test "ne peut pas accéder au dossier d'un autre user" do
    sign_in @user
    other = User.create!(email: "otherfold@test.com", password: "password123", first_name: "X", last_name: "Y")
    folder = other.folders.create!(name: "Secret folder")
    get folder_path(folder)
    assert_response :not_found
  end
end
