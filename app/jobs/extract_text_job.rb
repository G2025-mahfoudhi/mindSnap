class ExtractTextJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.file.attached?

    texts = []
    document.file.each do |attachment|
      text = FileExtractionService.extract(attachment.blob)
      texts << text if text.present?
    end

    if texts.any?
      document.update!(content: texts.join("\n\n"))
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "ExtractTextJob: document #{document_id} introuvable"
  rescue StandardError => e
    Rails.logger.error "ExtractTextJob échec doc #{document_id}: #{e.message}"
  end
end
