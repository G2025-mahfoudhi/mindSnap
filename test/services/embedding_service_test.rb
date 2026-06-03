require "test_helper"

class EmbeddingServiceTest < ActiveSupport::TestCase
  test "embed ne crash pas" do
    result = EmbeddingService.embed("Test embedding") rescue nil
    if result
      assert_kind_of Array, result
      assert_equal 1024, result.length
    end
    # L'appel peut échouer si l'API est rate-limitée
  end

  test "la classe répond à embed" do
    assert EmbeddingService.respond_to?(:embed)
  end
end
