require "test_helper"

class ExtractTextJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "extrait le texte et met à jour le contenu" do
    doc = @user.documents.create!(
      title: "Fichier test",
      document_type: "Fichier"
    )
    doc.file.attach(
      io: StringIO.new("Contenu du fichier texte."),
      filename: "test.txt",
      content_type: "text/plain"
    )

    ExtractTextJob.perform_now(doc.id)
    assert_equal "Contenu du fichier texte.", doc.reload.content
  end

  test "ne fait rien si pas de fichier attaché" do
    doc = @user.documents.create!(
      title: "Sans fichier",
      document_type: "Note"
    )

    assert_no_changes -> { doc.reload.content } do
      ExtractTextJob.perform_now(doc.id)
    end
  end

  test "ne crashe pas si document introuvable" do
    assert_nothing_raised do
      ExtractTextJob.perform_now(999_999)
    end
  end

  test "est dans la queue ai" do
    assert_equal "ai", ExtractTextJob.new.queue_name
  end

  test "concatène plusieurs fichiers joints" do
    doc = @user.documents.create!(
      title: "Multi fichiers",
      document_type: "Fichier"
    )
    doc.file.attach(
      io: StringIO.new("Premier fichier."),
      filename: "first.txt",
      content_type: "text/plain"
    )
    doc.file.attach(
      io: StringIO.new("Second fichier."),
      filename: "second.txt",
      content_type: "text/plain"
    )

    ExtractTextJob.perform_now(doc.id)
    result = doc.reload.content
    assert result.include?("Premier fichier")
    assert result.include?("Second fichier")
    assert result.include?("\n\n")
  end
end
