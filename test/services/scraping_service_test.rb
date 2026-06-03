require "test_helper"

class ScrapingServiceTest < ActiveSupport::TestCase
  test "fetch retourne nil pour URL invalide" do
    result = ScrapingService.fetch("not-a-url")
    assert_nil result
  end

  test "fetch retourne nil pour protocole non HTTP" do
    result = ScrapingService.fetch("ftp://example.com")
    assert_nil result
  end

  test "fetch gère les erreurs réseau" do
    result = ScrapingService.fetch("https://invalid.domain.that.does.not.exist.example")
    assert_nil result
  end

  test "la classe est chargée" do
    assert ScrapingService.respond_to?(:fetch)
  end
end
