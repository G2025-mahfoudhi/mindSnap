require "faraday"
require "faraday/follow_redirects"

class ScrapingService
  MAX_CONTENT_LENGTH = 50_000

  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
               "AppleWebKit/537.36 (KHTML, like Gecko) " \
               "Chrome/125.0.0.0 Safari/537.36"

  def self.fetch(url)
    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response = connection.get(uri.to_s)
    return nil unless response.success?

    doc = Nokogiri::HTML(response.body)
    doc.css("script, style, nav, footer, header, aside, noscript").remove
    doc.css("body").text.gsub(/\s+/, " ").strip.truncate(MAX_CONTENT_LENGTH)
  rescue URI::InvalidURIError
    nil
  rescue Faraday::TimeoutError => e
    Rails.logger.warn "ScrapingService timeout pour #{url}: #{e.message}"
    nil
  rescue Faraday::ConnectionFailed => e
    Rails.logger.warn "ScrapingService connexion échouée pour #{url}: #{e.message}"
    nil
  rescue Faraday::ClientError => e
    Rails.logger.warn "ScrapingService erreur client pour #{url}: #{e.message}"
    nil
  rescue Faraday::ServerError => e
    Rails.logger.warn "ScrapingService erreur serveur pour #{url}: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "ScrapingService échec inattendu pour #{url}: #{e.message}"
    nil
  end

  def self.connection
    @connection ||= Faraday.new do |f|
      f.response :follow_redirects
      f.options.open_timeout = 5
      f.options.timeout = 10
      f.headers["User-Agent"] = USER_AGENT
      f.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      f.headers["Accept-Language"] = "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
      f.adapter Faraday.default_adapter
    end
  end
end
