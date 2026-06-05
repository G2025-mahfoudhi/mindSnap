require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:test_user1)
  end

  # -- Tests existants -------------------------------------------------------

  test "valide avec titre et type" do
    document = Document.new(
      user: @user,
      title: "Mon document",
      document_type: "Note"
    )
    assert document.valid?
  end

  test "invalide sans titre" do
    document = Document.new(
      user: @user,
      document_type: "Note"
    )
    assert_not document.valid?
    assert_includes document.errors[:title].map(&:downcase).join, "blank"
  end

  test "invalide sans document_type" do
    document = Document.new(
      user: @user,
      title: "Mon document"
    )
    assert_not document.valid?
    assert_includes document.errors[:document_type].map(&:downcase).join, "blank"
  end

  test "appartient à un user" do
    document = Document.create!(
      user: @user,
      title: "Test",
      document_type: "Article"
    )
    assert_equal @user, document.user
  end

  test "embedding_status par défaut à pending" do
    document = Document.create!(
      user: @user,
      title: "Status test",
      document_type: "Note"
    )
    assert_equal "pending", document.embedding_status
  end

  test "a des document_chunks" do
    document = Document.create!(
      user: @user,
      title: "Chunks test",
      document_type: "Note"
    )
    assert_respond_to document, :document_chunks
    assert_equal 0, document.document_chunks.count
  end

  test "summary et source_url sont accessibles" do
    document = Document.create!(
      user: @user,
      title: "Meta test",
      document_type: "Lien",
      summary: "Un résumé",
      source_url: "https://example.com"
    )
    assert_equal "Un résumé", document.summary
    assert_equal "https://example.com", document.source_url
  end

  test "after_commit enqueue EmbedDocumentJob quand content présent" do
    assert_enqueued_with(job: EmbedDocumentJob) do
      Document.create!(
        user: @user,
        title: "Job test",
        content: "Du contenu pour l'embedding",
        document_type: "Note"
      )
    end
  end

  test "n'enqueue pas EmbedDocumentJob si content vide" do
    assert_no_enqueued_jobs do
      Document.create!(
        user: @user,
        title: "Sans contenu",
        document_type: "Note"
      )
    end
  end

  test "embedded? retourne true si status completed" do
    document = Document.create!(
      user: @user,
      title: "Embedded doc",
      content: "test",
      document_type: "Note",
      embedding_status: "completed"
    )
    assert document.embedded?
  end

  test "embedded? retourne false si status pending" do
    document = Document.create!(
      user: @user,
      title: "Pending doc",
      document_type: "Note"
    )
    assert_not document.embedded?
  end

  # -- Nouveaux tests : scraping et source_url -------------------------------

  test "after_commit enqueue ScrapeLinkJob pour un Lien avec source_url" do
    assert_enqueued_with(job: ScrapeLinkJob) do
      Document.create!(
        user: @user,
        title: "Scrape me",
        document_type: "Lien",
        source_url: "https://example.com"
      )
    end
  end

  test "n'enqueue pas ScrapeLinkJob pour une Note avec source_url" do
    assert_no_enqueued_jobs(only: ScrapeLinkJob) do
      Document.create!(
        user: @user,
        title: "Not a link",
        document_type: "Note",
        source_url: "https://example.com"
      )
    end
  end

  test "n'enqueue pas ScrapeLinkJob si Lien sans source_url" do
    assert_no_enqueued_jobs(only: ScrapeLinkJob) do
      Document.create!(
        user: @user,
        title: "Link no URL",
        document_type: "Lien"
      )
    end
  end

  test "n'enqueue pas ScrapeLinkJob si Lien avec source_url et contenu déjà présent" do
    assert_no_enqueued_jobs(only: ScrapeLinkJob) do
      Document.create!(
        user: @user,
        title: "Already has content",
        document_type: "Lien",
        source_url: "https://example.com",
        content: "Contenu déjà présent"
      )
    end
  end

  # -- Validation source_url -------------------------------------------------

  test "invalide avec source_url mal formée" do
    document = Document.new(
      user: @user,
      title: "Bad URL",
      document_type: "Lien",
      source_url: "pas-une-url"
    )
    assert_not document.valid?
    assert_includes document.errors[:source_url].join.downcase, "url"
  end

  test "valide avec source_url vide (allow_blank)" do
    document = Document.new(
      user: @user,
      title: "Empty URL",
      document_type: "Lien",
      source_url: ""
    )
    assert document.valid?
  end

  test "valide avec source_url nil (allow_blank)" do
    document = Document.new(
      user: @user,
      title: "Nil URL",
      document_type: "Lien",
      source_url: nil
    )
    assert document.valid?
  end

  # -- Legacy migration ------------------------------------------------------

  test "migre l'URL de content vers source_url pour les documents Lien legacy" do
    # Le create! déclenche déjà migrate_legacy_url (before_save).
    # On restaure l'état legacy en BDD pour tester manuellement la migration.
    doc = @user.documents.create!(
      title: "Legacy link",
      document_type: "Lien",
      content: "https://legacy.example.com"
    )
    doc.update_columns(
      source_url: nil,
      content: "https://legacy.example.com",
      scraping_status: "idle"
    )
    doc.reload

    # Le save! doit déclencher before_save :migrate_legacy_url
    doc.save!
    doc.reload

    assert_equal "https://legacy.example.com", doc.source_url,
                 "L'URL devrait être migrée de content vers source_url"
    assert_nil doc.content,
               "content devrait être nil après migration"
    assert_equal "pending", doc.scraping_status,
                 "scraping_status devrait être remis à pending après migration"
  end

  test "après migration legacy, ScrapeLinkJob est enqueued" do
    doc = @user.documents.create!(
      title: "Legacy link 2",
      document_type: "Lien",
      content: "https://legacy2.example.com"
    )
    doc.update_columns(
      source_url: nil,
      content: "https://legacy2.example.com",
      scraping_status: "idle"
    )
    doc.reload

    assert_enqueued_with(job: ScrapeLinkJob, args: [doc.id]) do
      doc.save!
    end
  end

  test "ne migre pas si document_type n'est pas Lien" do
    doc = @user.documents.create!(
      title: "Not a link",
      document_type: "Note",
      content: "https://should-not-migrate.example.com"
    )
    # Pour les Notes, le create! ne déclenche pas migrate_legacy_url
    # (should_migrate_url? vérifie document_type == "Lien")
    doc.update_columns(source_url: nil)
    doc.reload

    doc.save!
    doc.reload

    assert_nil doc.source_url,
               "source_url ne devrait pas être modifié pour une Note"
    assert_equal "https://should-not-migrate.example.com", doc.content,
                 "content ne devrait pas être effacé pour une Note"
  end

  test "ne migre pas si content ne commence pas par http" do
    # Même approche : on crée puis on restaure l'état legacy
    doc = @user.documents.create!(
      title: "Not an URL",
      document_type: "Lien",
      content: "Ceci n'est pas une URL"
    )
    doc.update_columns(source_url: nil, content: "Ceci n'est pas une URL")
    doc.reload

    doc.save!
    doc.reload

    assert_nil doc.source_url,
               "source_url ne devrait pas être modifié si content n'est pas une URL"
    assert_equal "Ceci n'est pas une URL", doc.content,
                 "content ne devrait pas être effacé si ce n'est pas une URL"
  end

  # -- scraping_status par défaut --------------------------------------------

  test "scraping_status par défaut à pending" do
    document = Document.create!(
      user: @user,
      title: "Scraping status test",
      document_type: "Lien",
      source_url: "https://example.com"
    )
    assert_equal "pending", document.scraping_status
  end

  test "scraping_status par défaut à pending même sans source_url" do
    document = Document.create!(
      user: @user,
      title: "Default scraping status",
      document_type: "Note"
    )
    assert_equal "pending", document.scraping_status
  end
end
