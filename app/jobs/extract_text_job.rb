class ExtractTextJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.file.attached?

    extracted = collect_texts(document)

    if extracted.empty?
      # Extraction échouée (OCR indisponible, format non supporté…)
      # On tente quand même le résumé si le document a déjà du contenu
      SummarizeDocumentJob.perform_later(document_id) if document.content.present?
      Rails.logger.warn "ExtractTextJob: aucun texte extrait pour doc #{document_id}"
      return
    end

    document.update!(content: build_content(extracted))
    SummarizeDocumentJob.perform_later(document_id)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "ExtractTextJob: document #{document_id} introuvable"
  rescue StandardError => e
    Rails.logger.error "ExtractTextJob échec doc #{document_id}: #{e.message}"
  end

  MAX_CHARS_PER_FILE = 3_000

  private

  def collect_texts(document)
    document.file.filter_map do |attachment|
      text = FileExtractionService.extract(attachment.blob)
      { filename: attachment.blob.filename.to_s, text: text } if text.present?
    rescue StandardError => e
      Rails.logger.warn "ExtractTextJob: extraction échouée #{attachment.blob.filename} — #{e.message}"
      nil
    end
  end

  def build_content(extracted)
    return extracted.first[:text] if extracted.size == 1

    extracted.each_with_index.map do |item, idx|
      "[Fichier #{idx + 1} : #{item[:filename]}]\n#{item[:text].strip.truncate(MAX_CHARS_PER_FILE)}"
    end.join("\n\n---\n\n")
  end
end
