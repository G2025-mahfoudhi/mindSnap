require "test_helper"

class SummarizeDocumentJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "perform ne crash pas pour un document avec contenu" do
    doc = @user.documents.create!(
      title: "Summarize test",
      content: "Le machine learning est une branche de l'intelligence artificielle qui permet aux ordinateurs d'apprendre sans être explicitement programmés.",
      document_type: "Note"
    )
    assert_nothing_raised do
      SummarizeDocumentJob.perform_now(doc.id)
    end
    doc.reload
    # Le résumé peut être nil si l'API échoue — le job gère ça sans crash
  end

  test "perform skip si contenu vide" do
    doc = @user.documents.create!(
      title: "Doc sans contenu",
      document_type: "Note"
    )
    assert_no_changes -> { doc.reload.summary } do
      SummarizeDocumentJob.perform_now(doc.id)
    end
  end

  test "est dans la queue ai" do
    assert_equal "ai", SummarizeDocumentJob.new.queue_name
  end
end
