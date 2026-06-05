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

  test "fetch suit les redirects via le middleware Faraday" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/") { |_env| [301, { "Location" => "/final" }, ""] }
      stub.get("/final") { |_env| [200, { "Content-Type" => "text/html" }, "<html><body>Contenu après redirect</body></html>"] }
    end

    conn = Faraday.new("http://redirect.test") do |f|
      f.response :follow_redirects
      f.adapter :test, stubs
    end

    old_conn = ScrapingService.instance_variable_get(:@connection)
    ScrapingService.instance_variable_set(:@connection, conn)

    result = ScrapingService.fetch("http://redirect.test/")
    assert_equal "Contenu après redirect", result
  ensure
    ScrapingService.instance_variable_set(:@connection, old_conn)
  end

  test "fetch retourne nil quand Faraday lève une exception" do
    conn = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get("/") { raise Faraday::TimeoutError.new("read timeout reached") }
      end
    end

    old_conn = ScrapingService.instance_variable_get(:@connection)
    ScrapingService.instance_variable_set(:@connection, conn)

    result = ScrapingService.fetch("https://timeout.example.com")
    assert_nil result
  ensure
    ScrapingService.instance_variable_set(:@connection, old_conn)
  end

  test "fetch retourne nil quand le serveur retourne une erreur" do
    conn = Faraday.new("http://error.test") do |f|
      f.response :follow_redirects
      f.adapter :test do |stub|
        stub.get("/") { |_env| [500, { "Content-Type" => "text/plain" }, "Internal Server Error"] }
      end
    end

    old_conn = ScrapingService.instance_variable_get(:@connection)
    ScrapingService.instance_variable_set(:@connection, conn)

    result = ScrapingService.fetch("http://error.test/")
    assert_nil result
  ensure
    ScrapingService.instance_variable_set(:@connection, old_conn)
  end
end
