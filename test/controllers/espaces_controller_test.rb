require "test_helper"

class EspacesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  test "redirige vers login si pas connecté" do
    get espaces_path
    assert_redirected_to new_user_session_path
  end

  test "accessible quand connecté" do
    sign_in @user
    get espaces_path
    assert_response :success
  end

  test "affiche les dossiers de l'utilisateur" do
    sign_in @user
    Folder.create!(name: "Dossier test", user: @user)
    get espaces_path
    assert_response :success
  end
end
