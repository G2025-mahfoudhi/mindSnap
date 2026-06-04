require "test_helper"

class DocumentChunkTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user1)
    @document = Document.create!(
      user: @user,
      title: "Test Document",
      content: "Contenu de test pour les chunks.",
      document_type: "Note"
    )
  end

  test "appartient à un document" do
    chunk = DocumentChunk.new(
      document: @document,
      chunk_index: 0,
      content: "Test content"
    )
    assert chunk.valid?
    assert_equal @document, chunk.document
  end

  test "requiert chunk_index" do
    chunk = DocumentChunk.new(
      document: @document,
      content: "Test"
    )
    assert_not chunk.valid?
    assert_includes chunk.errors[:chunk_index].map(&:downcase).join, "blank"
  end

  test "requiert content" do
    chunk = DocumentChunk.new(
      document: @document,
      chunk_index: 0
    )
    assert_not chunk.valid?
    assert_includes chunk.errors[:content].map(&:downcase).join, "blank"
  end

  test "peut stocker un embedding vectoriel" do
    chunk = DocumentChunk.create!(
      document: @document,
      chunk_index: 0,
      content: "Test",
      embedding: Array.new(1024, 0.0)
    )
    assert_not_nil chunk.embedding
    assert_equal 1024, chunk.embedding.length
  end

  test "has_neighbors est disponible" do
    assert DocumentChunk.respond_to?(:nearest_neighbors),
      "nearest_neighbors devrait être disponible via has_neighbors"
  end

  test "destroy en cascade depuis le document" do
    DocumentChunk.create!(
      document: @document,
      chunk_index: 0,
      content: "Test cascade"
    )
    assert_equal 1, @document.document_chunks.count
    @document.destroy
    assert_equal 0, DocumentChunk.where(document_id: @document.id).count
  end
end
