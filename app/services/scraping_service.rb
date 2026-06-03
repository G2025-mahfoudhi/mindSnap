class ScrapingService
  MAX_CONTENT_LENGTH = 50_000

  def self.fetch(url)
    uri = URI(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(response.body)
    doc.css("script, style, nav, footer, header, aside, noscript").remove
    doc.css("body").text.gsub(/\s+/, " ").strip.truncate(MAX_CONTENT_LENGTH)
  rescue StandardError => e
    Rails.logger.error "ScrapingService échec pour #{url}: #{e.message}"
    nil
  end
end
