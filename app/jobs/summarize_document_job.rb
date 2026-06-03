class SummarizeDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    summary = LlmCallService.oneshot(build_prompt(document.content))
    document.update!(summary: summary&.strip) if summary.present?
  rescue StandardError => e
    Rails.logger.error "SummarizeDocumentJob échec doc #{document_id}: #{e.message}"
  end

  private

  def build_prompt(content)
    <<~PROMPT
      Résume le document suivant en 3 phrases maximum.
      Sois concis et factuel. Ne commence pas par "Ce document..."
      ou "L'auteur...". Va directement au contenu essentiel.

      Document :
      #{content.truncate(4000)}
    PROMPT
  end
end
