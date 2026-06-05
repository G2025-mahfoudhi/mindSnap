require "test_helper"

class SummarizeDocumentJobTest < ActiveJob::TestCase
  setup do
    @user = users(:test_user1)
  end

  test "stocke le résumé en base quand l'API répond" do
    doc = @user.documents.create!(
      title: "Summarize test",
      content: "Le machine learning est une branche de l'intelligence artificielle.",
      document_type: "Note"
    )

    stub_llm_oneshot("Résumé généré par l'IA.") do
      SummarizeDocumentJob.perform_now(doc.id)
    end

    assert_equal "Résumé généré par l'IA.", doc.reload.summary
  end

  test "stocke un message d'erreur si l'API retourne nil" do
    doc = @user.documents.create!(
      title: "API fail test",
      content: "Un contenu quelconque.",
      document_type: "Note"
    )

    original = LlmCallService.method(:oneshot)
    LlmCallService.define_singleton_method(:oneshot) { |*_args| nil }
    SummarizeDocumentJob.perform_now(doc.id)
    assert_match(/indisponible/, doc.reload.summary.to_s)
  ensure
    LlmCallService.define_singleton_method(:oneshot, original)
  end

  test "ne crashe pas si l'API lève une exception" do
    doc = @user.documents.create!(
      title: "Crash test",
      content: "Contenu",
      document_type: "Note"
    )

    original = LlmCallService.method(:oneshot)
    LlmCallService.define_singleton_method(:oneshot) { |*_args| raise StandardError, "boom" }
    assert_nothing_raised { SummarizeDocumentJob.perform_now(doc.id) }
  ensure
    LlmCallService.define_singleton_method(:oneshot, original)
  end

  test "skip si contenu vide" do
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

  test "strip le résumé avant stockage" do
    doc = @user.documents.create!(
      title: "Strip test",
      content: "Du contenu.",
      document_type: "Note"
    )

    stub_llm_oneshot("  Résumé avec espaces  \n") do
      SummarizeDocumentJob.perform_now(doc.id)
    end

    assert_equal "Résumé avec espaces", doc.reload.summary
  end

  private

  def stub_llm_oneshot(return_value)
    original = LlmCallService.method(:oneshot)
    LlmCallService.define_singleton_method(:oneshot) { |*_args| return_value }
    yield
  ensure
    LlmCallService.define_singleton_method(:oneshot, original)
  end
end
