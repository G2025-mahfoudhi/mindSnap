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
    assert_includes ["scraped", "failed"], doc.scraping_status
  end

  test "perform skip si pas un Lien" do
    doc = @user.documents.create!(
      title: "Not a link",
      document_type: "Note",
      source_url: "https://example.com"
    )
    assert_no_changes -> { doc.reload.scraping_status } do
      ScrapeLinkJob.perform_now(doc.id)
    end
  end

  test "perform skip si pas d'URL source" do
    doc = @user.documents.create!(
      title: "Lien sans URL",
      document_type: "Lien"
    )
    assert_no_changes -> { doc.reload.scraping_status } do
      ScrapeLinkJob.perform_now(doc.id)
    end
  end

  test "est dans la queue ai" do
    assert_equal "ai", ScrapeLinkJob.new.queue_name
  end
end
