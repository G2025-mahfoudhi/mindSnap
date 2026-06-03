require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  test "redirige vers login si pas connecté" do
    get documents_path
    assert_redirected_to new_user_session_path
  end

  test "get index" do
    sign_in @user
    get documents_path
    assert_response :success
  end

  test "get new" do
    sign_in @user
    get new_document_path
    assert_response :success
  end

  test "create document avec titre et type" do
    sign_in @user
    assert_difference("Document.count", 1) do
      post documents_path, params: {
        document: { title: "Nouveau doc", content: "Contenu", document_type: "Note" }
      }
    end
    assert_redirected_to document_path(Document.last)
  end

  test "create document échoue sans titre" do
    sign_in @user
    assert_no_difference("Document.count") do
      post documents_path, params: {
        document: { title: "", document_type: "Note" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "get show" do
    sign_in @user
    doc = @user.documents.create!(title: "Show test", document_type: "Note")
    get document_path(doc)
    assert_response :success
  end

  test "get edit" do
    sign_in @user
    doc = @user.documents.create!(title: "Edit test", document_type: "Note")
    get edit_document_path(doc)
    assert_response :success
  end

  test "update document" do
    sign_in @user
    doc = @user.documents.create!(title: "Old title", document_type: "Note")
    patch document_path(doc), params: {
      document: { title: "New title" }
    }
    assert_redirected_to document_path(doc)
    assert_equal "New title", doc.reload.title
  end

  test "destroy document" do
    sign_in @user
    doc = @user.documents.create!(title: "Destroy test", document_type: "Note")
    assert_difference("Document.count", -1) do
      delete document_path(doc)
    end
    assert_response :see_other
  end

  test "ne peut pas accéder au document d'un autre user" do
    sign_in @user
    other = User.create!(email: "other@test.com", password: "password123")
    doc = other.documents.create!(title: "Secret", document_type: "Note")
    get document_path(doc)
    assert_response :not_found
  end

  test "create avec nouveau dossier" do
    sign_in @user
    assert_difference("Folder.count", 1) do
      post documents_path, params: {
        document: { title: "Doc dans nouveau dossier", document_type: "Note", folder_id: "new" },
        new_folder_name: "Dossier créé à la volée"
      }
    end
  end
end
