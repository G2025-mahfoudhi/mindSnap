require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user1)
    sign_in @user

    # Stub EmbeddingService.embed pour des tests déterministes
    stub_embedding(test_vector("query stub"))
  end

  test "get search sans query affiche la page" do
    get search_path
    assert_response :success
    assert_select "h1", "Recherche intelligente"
  end

  test "get search avec query vide ne lance pas la recherche" do
    get search_path, params: { q: "" }
    assert_response :success
    assert_select ".doc-card", false, "Aucune card ne doit être affichée pour une query vide"
  end

  test "get search avec query affiche les docs pertinents tries par score" do
    doc_close = Document.create!(user: @user, title: "Pertinent", content: "x", document_type: "Note")
    DocumentChunk.create!(document: doc_close, chunk_index: 0, content: "x", embedding: test_vector("query stub"))
    doc_far = Document.create!(user: @user, title: "Pas pertinent", content: "y", document_type: "Note")
    DocumentChunk.create!(document: doc_far, chunk_index: 0, content: "y", embedding: test_vector("autre seed xyz"))

    get search_path, params: { q: "test" }
    assert_response :success

    # Le doc "Pertinent" (embedding quasi-identique) doit apparaître
    assert_select "h2.h6", text: /Pertinent/
    # Le doc "Pas pertinent" (embedding orthogonal) doit être filtré
    assert_select "h2.h6", text: /Pas pertinent/, count: 0
  end

  test "search affiche le badge de pertinence sur la page de resultats" do
    doc = Document.create!(user: @user, title: "Doc test", content: "x", document_type: "Note")
    DocumentChunk.create!(document: doc, chunk_index: 0, content: "x", embedding: test_vector("query stub"))

    get search_path, params: { q: "test" }
    assert_response :success
    assert_select ".badge", text: /% pertinent/
  end

  test "search n'affiche pas le badge de pertinence sur d'autres pages" do
    # Sur la page "Mon espace", les cards n'ont pas de score
    doc = Document.create!(user: @user, title: "Doc test", content: "x", document_type: "Note")

    get espaces_path
    assert_response :success
    assert_select ".badge", text: /% pertinent/, count: 0
  end

  test "search gere les erreurs d'API gracieusement" do
    # Stub qui lève une exception (simule un crash API)
    original = EmbeddingService.method(:embed)
    EmbeddingService.define_singleton_method(:embed) { |*_args| raise StandardError, "API down" }
    get search_path, params: { q: "test" }
    EmbeddingService.define_singleton_method(:embed, original)
    assert_response :success
    # Message d'erreur rendu via flash[:alert] (.alert-warning) ou dans le HTML
    assert_select ".alert", text: /indisponible/
  end

  private

  # Génère un vecteur déterministe (cf. RagServiceTest).
  def test_vector(keywords)
    seed = keywords.hash
    rng = Random.new(seed)
    Array.new(1024) { rng.rand(-1.0..1.0) }
  end

  # Stub EmbeddingService.embed pour la durée du test.
  def stub_embedding(value)
    original = EmbeddingService.method(:embed)
    EmbeddingService.define_singleton_method(:embed) { |*_args| value }
    @original_embed = original
  end

  def teardown
    if @original_embed
      EmbeddingService.define_singleton_method(:embed, @original_embed)
    end
  end
end
