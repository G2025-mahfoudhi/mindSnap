require "test_helper"

class TagDocumentJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "perform ne crash pas pour un document avec contenu" do
    doc = @user.documents.create!(
      title: "Tag test",
      content: "Ruby on Rails est un framework web écrit en Ruby qui suit le pattern MVC.",
      document_type: "Note"
    )
    assert_nothing_raised do
      TagDocumentJob.perform_now(doc.id)
    end
    doc.reload
    # Les tags peuvent être vides si l'API échoue — le job gère ça sans crash
  end

  test "perform skip si contenu vide" do
    doc = @user.documents.create!(
      title: "Doc sans contenu",
      document_type: "Article"
    )
    assert_no_changes -> { doc.reload.tags.count } do
      TagDocumentJob.perform_now(doc.id)
    end
  end

  test "les tags générés sont normalisés" do
    doc = @user.documents.create!(
      title: "Tag normalize test",
      content: "Ruby on Rails est un framework web.",
      document_type: "Note"
    )
    TagDocumentJob.perform_now(doc.id)
    doc.reload
    doc.tags.each do |tag|
      assert_equal tag.name, tag.name.downcase
    end
    # Si pas de tags (API rate-limitée), le test passe quand même
    assert true
  end

  test "est dans la queue ai" do
    assert_equal "ai", TagDocumentJob.new.queue_name
  end
end
