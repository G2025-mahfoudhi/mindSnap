# Job asynchrone de scraping pour les documents de type "Lien".
# Appelle ScrapingService pour extraire le contenu de l'URL source,
# puis relance l'embedding du document avec le nouveau contenu.
class ScrapeLinkJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.document_type == "Lien"
    return if document.source_url.blank?

    document.update!(scraping_status: "scraping")

    content = ScrapingService.fetch(document.source_url)

    if content.present?
      document.update!(
        content: content,
        scraping_status: "scraped"
      )
      EmbedDocumentJob.perform_later(document_id)
    else
      document.update!(scraping_status: "failed")
    end
  rescue StandardError => e
    document.update!(scraping_status: "failed")
    Rails.logger.error "ScrapeLinkJob échec doc #{document_id}: #{e.message}"
  end
end
