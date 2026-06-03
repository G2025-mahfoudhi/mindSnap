require "test_helper"

class RagServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
    @document = Document.create!(
      user: @user,
      title: "Machine Learning Basics",
      content: "Le machine learning est une branche de l'IA.",
      document_type: "Note"
    )

    # Créer des chunks avec embeddings simulés (cosine search sur vecteurs)
    @chunk_ml = DocumentChunk.create!(
      document: @document,
      chunk_index: 0,
      content: "Le machine learning est une branche de l'intelligence artificielle.",
      embedding: test_vector("machine learning intelligence artificielle")
    )

    @doc2 = Document.create!(
      user: @user,
      title: "Cuisine italienne",
      content: "Recette de pasta.",
      document_type: "Note"
    )

    @chunk_cuisine = DocumentChunk.create!(
      document: @doc2,
      chunk_index: 0,
      content: "La recette des pâtes carbonara.",
      embedding: test_vector("cuisine recette pates carbonara")
    )
  end

  test "initialise avec un user" do
    rag = RagService.new(@user)
    assert_instance_of RagService, rag
  end

  test "search retourne des résultats" do
    rag = RagService.new(@user)
    results = rag.search("machine learning", limit: 5)
    assert results.any?, "La recherche devrait retourner au moins un résultat"
    assert_kind_of DocumentChunk, results.first
  end

  test "search trouve le document pertinent sur le ML" do
    rag = RagService.new(@user)
    results = rag.search("intelligence artificielle", limit: 5)
    titles = results.map { |c| c.document.title }.uniq
    assert_includes titles, "Machine Learning Basics"
  end

  test "format_context retourne du texte structuré" do
    rag = RagService.new(@user)
    results = rag.search("machine learning", limit: 2)
    context = rag.format_context(results)

    assert context.present?
    assert_includes context, "[Document:"
    assert_includes context, "Type:"
    assert_includes context, "Machine Learning Basics"
  end

  test "format_context retourne nil pour tableau vide" do
    rag = RagService.new(@user)
    assert_nil rag.format_context([])
  end

  test "format_context retourne nil pour nil" do
    rag = RagService.new(@user)
    assert_nil rag.format_context(nil)
  end

  test "search avec des mots sans rapport retourne quand même des résultats" do
    rag = RagService.new(@user)
    results = rag.search("xyzabc totalement aléatoire sans sens", limit: 2)
    # La recherche vectorielle retourne toujours les vecteurs les plus proches
    assert results.any?, "Même pour une requête sans rapport, des résultats sont retournés (top-N)"
  end

  private

  # Génére un vecteur déterministe basé sur les mots-clés
  # pour avoir des embeddings cohérents en test (pas d'appel API)
  def test_vector(keywords)
    seed = keywords.hash
    rng = Random.new(seed)
    Array.new(1024) { rng.rand(-1.0..1.0) }
  end
end
