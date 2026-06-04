require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    sign_in @user
  end

  test "get search sans query affiche la page" do
    get search_path
    assert_response :success
    assert_select "h1", "Recherche intelligente"
  end

  test "get search avec query vide" do
    get search_path, params: { q: "" }
    assert_response :success
  end

  test "get search avec query" do
    doc = Document.create!(
      user: @user,
      title: "Document test recherche",
      content: "Contenu de test",
      document_type: "Note"
    )
    get search_path, params: { q: "test" }
    assert_response :success
  end
end
