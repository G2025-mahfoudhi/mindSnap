class RagService
  def initialize(user)
    @user = user
  end

  def search(query, folder_id: nil, limit: 5)
    query_embedding = EmbeddingService.embed(query)
    return [] unless query_embedding

    scope = DocumentChunk
      .joins(:document)
      .where(documents: { user_id: @user.id })

    scope = scope.where(documents: { folder_id: folder_id }) if folder_id

    scope
      .nearest_neighbors(:embedding, query_embedding)
      .limit(limit)
      .includes(:document)
  end

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
