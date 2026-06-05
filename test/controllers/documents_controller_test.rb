require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
  end

  # -- Tests existants -------------------------------------------------------

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

  test "summarize enqueue le job et redirige" do
    sign_in @user
    doc = @user.documents.create!(title: "À résumer", content: "Du contenu.", document_type: "Note")

    assert_enqueued_with(job: SummarizeDocumentJob, args: [doc.id]) do
      post summarize_document_path(doc)
    end

    assert_redirected_to document_path(doc)
    assert_equal "Résumé en cours de génération…", flash[:notice]
  end

  test "summarize redirige avec alerte si contenu vide" do
    sign_in @user
    doc = @user.documents.create!(title: "Sans contenu", document_type: "Note")

    assert_no_enqueued_jobs do
      post summarize_document_path(doc)
    end

    assert_redirected_to document_path(doc)
    assert_equal "Le document n'a pas de contenu à résumer.", flash[:alert]
  end

  test "ne peut pas summarize le document d'un autre user" do
    sign_in @user
    other = User.create!(email: "other2@test.com", password: "password123")
    doc = other.documents.create!(title: "Secret", content: "secret", document_type: "Note")

    post summarize_document_path(doc)
    assert_response :not_found
  end

  test "summary_status retourne le résumé en JSON" do
    sign_in @user
    doc = @user.documents.create!(
      title: "JSON test",
      content: "Du contenu.",
      document_type: "Note",
      summary: "Un résumé."
    )

    get summary_status_document_path(doc)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Un résumé.", json["summary"]
  end

  test "summary_status retourne null si pas de résumé" do
    sign_in @user
    doc = @user.documents.create!(title: "Sans résumé", document_type: "Note")

    get summary_status_document_path(doc)
    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["summary"]
  end

  # -- Nouveaux tests : create avec source_url -------------------------------

  test "create document Lien avec source_url" do
    sign_in @user
    assert_difference("Document.count", 1) do
      post documents_path, params: {
        document: {
          title: "Mon lien",
          source_url: "https://blog.example.com/article",
          document_type: "Lien"
        }
      }
    end
    assert_redirected_to document_path(Document.last)
    assert_equal "https://blog.example.com/article", Document.last.source_url
  end

  test "create document Lien avec source_url et content vide" do
    sign_in @user
    post documents_path, params: {
      document: {
        title: "Lien sans contenu",
        source_url: "https://scrape-me.example.com",
        document_type: "Lien",
        content: ""
      }
    }
    assert_redirected_to document_path(Document.last)
    doc = Document.last
    assert_equal "https://scrape-me.example.com", doc.source_url
    assert_equal "Lien", doc.document_type
  end

  test "create document avec source_url invalide échoue" do
    sign_in @user
    assert_no_difference("Document.count") do
      post documents_path, params: {
        document: {
          title: "Mauvaise URL",
          source_url: "pas-une-url-valide",
          document_type: "Lien"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # -- Test d'édition pour documents legacy ----------------------------------

  test "get edit pré-remplit source_url pour les documents Lien legacy" do
    sign_in @user
    # Le before_save :migrate_legacy_url déplace déjà content → source_url
    # au premier save. On restaure l'état legacy pour tester l'action edit.
    doc = @user.documents.create!(
      title: "Legacy",
      document_type: "Lien",
      content: "https://ancien-site.com/page"
    )
    doc.update_columns(source_url: nil, content: "https://ancien-site.com/page")

    get edit_document_path(doc)
    assert_response :success
    # L'action edit copie content → @document.source_url pour l'affichage
    assert_match(/ancien-site\.com/, response.body,
                 "Le formulaire devrait afficher l'URL legacy")
  end
end
