# Job asynchrone de génération d'embeddings pour un document.
# 1. Découpe le contenu en chunks via ChunkingService
# 2. Génère un vecteur par chunk via EmbeddingService (OpenRouter)
# 3. Stocke les chunks + vecteurs dans document_chunks
# 4. Chaîne les jobs de résumé et de tagging (Phase 3)
class EmbedDocumentJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    return if document.content.blank?

    document.update!(embedding_status: "processing")

    document.document_chunks.destroy_all

    chunks = ChunkingService.new(document.content).call
    chunks.each_with_index do |content, idx|
      embedding = EmbeddingService.embed(content)
      next unless embedding

      document.document_chunks.create!(
        chunk_index: idx,
        content: content,
        token_count: content.length / 4,
        embedding: embedding
      )
    end

    document.update!(embedding_status: "completed")

    # Chaînage — Phases 3+
    SummarizeDocumentJob.perform_later(document_id) if defined?(SummarizeDocumentJob)
    TagDocumentJob.perform_later(document_id) if defined?(TagDocumentJob)
  rescue StandardError => e
    document.update!(embedding_status: "failed")
    Rails.logger.error "EmbedDocumentJob échec doc #{document_id}: #{e.message}"
  end
end
