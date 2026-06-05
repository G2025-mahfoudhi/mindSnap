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
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "ScrapeLinkJob: document #{document_id} introuvable"
  rescue StandardError => e
    Document.where(id: document_id).update_all(scraping_status: "failed")
    Rails.logger.error "ScrapeLinkJob échec doc #{document_id}: #{e.message}"
  end
end
