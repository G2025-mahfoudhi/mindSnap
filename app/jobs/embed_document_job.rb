class EmbedDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    document.update!(embedding_status: "processing")

    chunks = ChunkingService.new(document.content).call
    new_chunks = []

    chunks.each_with_index do |content, idx|
      embedding = EmbeddingService.embed(content)
      unless embedding
        Rails.logger.warn "EmbedDocumentJob: chunk #{idx} ignoré pour doc #{document_id}"
        next
      end

      new_chunks << {
        chunk_index: idx,
        content: content,
        token_count: content.length / 4,
        embedding: embedding
      }
    end

    DocumentChunk.transaction do
      document.document_chunks.destroy_all
      new_chunks.each do |attrs|
        document.document_chunks.create!(attrs)
      end
    end

    document.update!(embedding_status: "completed")

    TagDocumentJob.perform_later(document_id)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "EmbedDocumentJob: document #{document_id} introuvable"
  rescue StandardError => e
    Document.where(id: document_id).update_all(embedding_status: "failed")
    Rails.logger.error "EmbedDocumentJob échec doc #{document_id}: #{e.message}"
  end
end
