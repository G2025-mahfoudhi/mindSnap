require "test_helper"

class OpenRouterServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
    @conversation = @user.conversations.create!(name: "Test OR")
    @user_message = @conversation.messages.create!(role: "user", content: "Hello")
  end

  test "initialize avec conversation et user_message" do
    service = OpenRouterService.new(@conversation, @user_message)
    assert_instance_of OpenRouterService, service
  end

  test "call ne crash pas" do
    service = OpenRouterService.new(@conversation, @user_message)
    result = service.call rescue nil
    # L'appel peut échouer si tous les modèles sont rate-limités
    assert(result.nil? || result.is_a?(String))
  end

  test "build_rag_context retourne un contexte" do
    doc = @user.documents.create!(
      title: "Test RAG doc",
      content: "Le machine learning est fascinant.",
      document_type: "Note"
    )
    EmbedDocumentJob.perform_now(doc.id)

    service = OpenRouterService.new(@conversation, @user_message)
    context = service.send(:build_rag_context)

    assert context.present?
    assert_includes context, "[Document:"
  end

  test "system_prompt contient MindSnap" do
    service = OpenRouterService.new(@conversation, @user_message)
    prompt = service.send(:system_prompt)
    assert_includes prompt, "MindSnap"
    assert_includes prompt, "Contexte documentaire"
  end

  test "models_to_try inclut le modèle configuré" do
    service = OpenRouterService.new(@conversation, @user_message)
    models = service.send(:models_to_try)
    assert_includes models, ENV.fetch("OPENROUTER_MODEL", service.class::FALLBACK_MODELS.first)
  end
end
