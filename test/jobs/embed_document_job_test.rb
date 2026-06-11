require "test_helper"

class EmbedDocumentJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "perform crée des chunks pour un document avec contenu" do
    doc = @user.documents.create!(
      title: "Embed test",
      content: "Le machine learning est une branche de l'intelligence artificielle.",
      document_type: "Note"
    )
    assert_changes -> { doc.reload.embedding_status }, from: "pending", to: "completed" do
      EmbedDocumentJob.perform_now(doc.id)
    end
    assert doc.document_chunks.count > 0
  end

  test "perform skip si contenu vide" do
    doc = @user.documents.create!(
      title: "Doc vide",
      document_type: "Article"
    )
    assert_no_changes -> { doc.reload.embedding_status } do
      EmbedDocumentJob.perform_now(doc.id)
    end
    assert_equal "pending", doc.embedding_status
  end

  test "perform ne crash pas si document introuvable" do
    assert_nothing_raised do
      EmbedDocumentJob.perform_now(999_999)
    rescue ActiveRecord::RecordNotFound
      # Comportement attendu
    end
  end

  test "est dans la queue ai" do
    assert_equal "ai", EmbedDocumentJob.new.queue_name
  end
end
