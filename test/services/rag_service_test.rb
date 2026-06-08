require "test_helper"

class RagServiceTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
  setup do
    @user = users(:test_user1)
    # Stub EmbeddingService.embed pour des tests déterministes
    stub_embedding(test_vector("query stub"))
    create_test_documents
  end

  # --- search() : chunks pour RAG chat --------------------------------------

  test "initialise avec un user" do
    rag = RagService.new(@user)
    assert_instance_of RagService, rag
  end

  test "search retourne des chunks quand la query est pertinente" do
    rag = RagService.new(@user)
    results = rag.search("n'importe quoi", limit: 5)
    assert results.any?, "La recherche devrait retourner au moins un chunk pertinent"
    assert_kind_of DocumentChunk, results.first
  end

  test "search filtre les chunks non pertinents (cosine > 0.35)" do
    rag = RagService.new(@user)
    results = rag.search("n'importe quoi", limit: 10)
    titles = results.map { |c| c.document.title }.uniq
    # Le doc cuisine a un embedding orthogonal → doit être filtré
    refute_includes titles, "Cuisine italienne",
                    "Le doc 'Cuisine italienne' (embedding orthogonal) doit être filtré par le seuil cosine"
    # Le doc ML a un embedding quasi-identique à la query stub → doit passer
    assert_includes titles, "Machine Learning Basics"
  end

  test "search trie par cosine distance croissante" do
    rag = RagService.new(@user)
    results = rag.search("n'importe quoi", limit: 5)
    distances = results.map { |c| c.neighbor_distance.to_f }
    assert_equal distances.sort, distances, "Les chunks doivent être triés par distance croissante"
  end

  # --- search_documents() : scoring hybride UI ------------------------------

  test "search_documents retourne uniquement les docs au-dessus du seuil" do
    rag = RagService.new(@user)
    results = rag.search_documents("machine learning", limit: 10)
    titles = results.map { |r| r[:document].title }
    # Doc ML a embedding quasi-identique → score élevé → présent
    assert_includes titles, "Machine Learning Basics"
    # Doc cuisine a embedding orthogonal → score trop bas → filtré
    refute_includes titles, "Cuisine italienne"
  end

  test "search_documents retourne un hash { document:, score: }" do
    rag = RagService.new(@user)
    results = rag.search_documents("machine learning", limit: 5)
    assert results.any?
    first = results.first
    assert_kind_of Document, first[:document]
    assert_kind_of Float, first[:score]
    assert first[:score] >= RagService::RELEVANCE_FLOOR
    assert first[:score] <= 1.0
  end

  test "search_documents trie par score décroissant" do
    rag = RagService.new(@user)
    # Crée 2 docs avec embeddings de qualité différente
    doc_close = Document.create!(user: @user, title: "Proche", content: "x", document_type: "Note")
    DocumentChunk.create!(document: doc_close, chunk_index: 0, content: "x", embedding: test_vector("query stub"))
    doc_far = Document.create!(user: @user, title: "Loin", content: "y", document_type: "Note")
    DocumentChunk.create!(document: doc_far, chunk_index: 0, content: "y", embedding: test_vector("autre seed xyz"))

    results = rag.search_documents("query", limit: 10)
    scores = results.map { |r| r[:score] }
    assert_equal scores.sort.reverse, scores
  end

  test "search_documents vide si aucun doc pertinent" do
    DocumentChunk.delete_all
    rag = RagService.new(@user)
    results = rag.search_documents("n'importe quoi", limit: 5)
    assert_empty results
  end

  test "search_documents vide pour query vide" do
    rag = RagService.new(@user)
    assert_empty rag.search_documents("", limit: 5)
    assert_empty rag.search_documents(nil, limit: 5)
  end

  test "search_documents vide si EmbeddingService retourne nil" do
    stub_embedding(nil)
    rag = RagService.new(@user)
    assert_empty rag.search_documents("test", limit: 5)
  end

  # --- format_context() ----------------------------------------------------

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

  private

  # Crée les 2 documents de test : un pertinent (embedding quasi-identique à la
  # query stub) et un non-pertinent (embedding orthogonal, sera filtré).
  def create_test_documents
    @document = create_ml_document
    @doc2 = create_cuisine_document
    @chunk_cuisine = create_chunk_for(@doc2, "La recette des pâtes carbonara.", "autre seed totalement different xyz")
  end

  def create_ml_document
    doc = Document.create!(
      user: @user,
      title: "Machine Learning Basics",
      content: "Le machine learning est une branche de l'IA.",
      document_type: "Note"
    )
    @chunk_ml = create_chunk_for(doc, "Le machine learning est une branche de l'intelligence artificielle.",
                                 "query stub")
    doc
  end

  def create_cuisine_document
    Document.create!(
      user: @user,
      title: "Cuisine italienne",
      content: "Recette de pasta carbonara.",
      document_type: "Note"
    )
  end

  def create_chunk_for(document, content, vector_seed)
    DocumentChunk.create!(
      document: document,
      chunk_index: 0,
      content: content,
      embedding: test_vector(vector_seed)
    )
  end

  # Génère un vecteur déterministe à partir d'une chaîne (seed = hash).
  # Utilisé pour avoir des embeddings cohérents en test (pas d'appel API).
  def test_vector(keywords)
    seed = keywords.hash
    rng = Random.new(seed)
    Array.new(1024) { rng.rand(-1.0..1.0) }
  end

  # Stub EmbeddingService.embed pour la durée du test (pattern du projet).
  def stub_embedding(value)
    original = EmbeddingService.method(:embed)
    EmbeddingService.define_singleton_method(:embed) { |*_args| value }
    @original_embed = original
  end

  def teardown
    return unless @original_embed

    EmbeddingService.define_singleton_method(:embed, @original_embed)
  end
end
