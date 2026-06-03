require "test_helper"

class ChunkingServiceTest < ActiveSupport::TestCase
  test "retourne un tableau" do
    result = ChunkingService.new("Hello world").call
    assert_kind_of Array, result
  end

  test "texte court donne un seul chunk" do
    result = ChunkingService.new("Ceci est un test simple.").call
    assert_equal 1, result.length
  end

  test "paragraphes multiples donnent au moins un chunk" do
    text = "Paragraphe un.\n\nParagraphe deux.\n\nParagraphe trois."
    result = ChunkingService.new(text).call
    assert result.length >= 1
  end

  test "texte vide donne un tableau vide" do
    result = ChunkingService.new("").call
    assert result.first.blank? || result.empty?
  end

  test "ne coupe pas au milieu d'une phrase" do
    text = "Phrase un. Phrase deux. Phrase trois. " * 50
    result = ChunkingService.new(text).call
    result.each do |chunk|
      last_char = chunk.strip[-1]
      assert_includes [".", "!", "?"], last_char,
        "Chunk devrait finir par une ponctuation, pas '#{last_char}'"
    end
  end

  test "les chunks contiennent le texte original" do
    text = "Introduction. " * 100 + "\n\n" + "Conclusion. " * 50
    result = ChunkingService.new(text).call
    combined = result.join(" ")
    assert_includes combined, "Introduction"
    assert_includes combined, "Conclusion"
  end
end
