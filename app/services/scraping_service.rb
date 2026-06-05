# Extrait le contenu textuel d'une page web via Nokogiri.
# Supprime les éléments non pertinents (scripts, nav, footer, etc.)
# et limite la sortie à MAX_CONTENT_LENGTH caractères.
class ScrapingService
  MAX_CONTENT_LENGTH = 50_000

  def self.fetch(url)
    uri = URI(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 10
    http.use_ssl = true if uri.scheme == "https"

    response = http.request_get(uri.request_uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(response.body)
    doc.css("script, style, nav, footer, header, aside, noscript").remove
    doc.css("body").text.gsub(/\s+/, " ").strip.truncate(MAX_CONTENT_LENGTH)
  rescue StandardError => e
    Rails.logger.error "ScrapingService échec pour #{url}: #{e.message}"
    nil
  end
end
