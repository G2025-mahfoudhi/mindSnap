# Service de Retrieval Augmented Generation (RAG).
# Recherche les chunks de documents les plus pertinents par similarité cosinus
# via pgvector, puis formate le contexte pour l'injection dans le prompt LLM.
class RagService
  def initialize(user)
    @user = user
  end

  # Recherche vectorielle : transforme la query en embedding, puis cherche
  # les chunks les plus proches via nearest_neighbors (cosine distance)
  def search(query, folder_id: nil, limit: 5)
    query_embedding = EmbeddingService.embed(query)
    return [] unless query_embedding

    scope = DocumentChunk
            .joins(:document)
            .where(documents: { user_id: @user.id })

    scope = scope.where(documents: { folder_id: folder_id }) if folder_id

    scope
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
      .includes(:document)
  end

  # Formate les chunks en un bloc de contexte structuré pour le prompt LLM.
  # Groupe les chunks par document et préfixe chaque bloc avec le titre.
  def format_context(chunks)
    return nil if chunks.blank?

    chunks.group_by(&:document).map do |document, doc_chunks|
      <<~CONTEXT
        [Document: "#{document.title}" — Type: #{document.document_type}]
        #{doc_chunks.map(&:content).join("\n---\n")}
      CONTEXT
    end.join("\n\n")
  end
end
