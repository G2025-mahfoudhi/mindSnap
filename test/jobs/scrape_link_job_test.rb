require "test_helper"

class ScrapeLinkJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "perform scrape un document Lien avec URL" do
    doc = @user.documents.create!(
      title: "Scrape test",
      document_type: "Lien",
      source_url: "https://example.com"
    )
    ScrapeLinkJob.perform_now(doc.id)
    doc.reload
    assert_includes %w[scraped failed], doc.scraping_status
  end

  test "perform skip si pas un Lien" do
    doc = @user.documents.create!(
      title: "Not a link",
      content: "x",
      document_type: "Note",
      source_url: "https://example.com"
    )
    assert_no_changes -> { doc.reload.scraping_status } do
      ScrapeLinkJob.perform_now(doc.id)
    end
  end

  test "perform skip si pas d'URL source" do
    doc = @user.documents.build(
      title: "Lien sans URL",
      document_type: "Lien"
    )
    doc.save(validate: false)
    assert_no_changes -> { doc.reload.scraping_status } do
      ScrapeLinkJob.perform_now(doc.id)
    end
  end

  test "est dans la queue ai" do
    assert_equal "ai", ScrapeLinkJob.new.queue_name
  end

  test "n'enqueue pas EmbedDocumentJob explicitement (bug du double job corrigé)" do
    doc = @user.documents.create!(
      title: "Double job test",
      document_type: "Lien",
      source_url: "https://example.com",
      embedding_status: "completed"
    )

    # On désactive le callback after_commit :embed_async pour isoler
    # le comportement du job et vérifier qu'il n'appelle pas EmbedDocumentJob
    Document.skip_callback(:commit, :after, :embed_async, raise: false)

    assert_no_enqueued_jobs(only: EmbedDocumentJob) do
      ScrapeLinkJob.perform_now(doc.id)
    end
  ensure
    Document.set_callback(:commit, :after, :embed_async)
  end

  test "perform de bout en bout : création Lien → scraping → status scraped/failed" do
    doc = @user.documents.create!(
      title: "E2E scrape",
      document_type: "Lien",
      source_url: "https://example.com"
    )

    assert_equal "pending", doc.scraping_status

    ScrapeLinkJob.perform_now(doc.id)
    doc.reload

    assert_includes %w[scraped failed], doc.scraping_status,
                    "Le statut devrait être scraped ou failed après le job"
  end

  test "perform gère un document qui n'existe plus" do
    doc = @user.documents.create!(
      title: "À supprimer",
      document_type: "Lien",
      source_url: "https://example.com"
    )
    doc_id = doc.id
    doc.destroy!

    # Ne doit pas lever d'exception
    assert_nothing_raised do
      ScrapeLinkJob.perform_now(doc_id)
    end
  end
end
