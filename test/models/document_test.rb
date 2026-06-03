require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:test_user1)
  end

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
end
