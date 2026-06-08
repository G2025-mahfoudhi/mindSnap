# Service de Retrieval Augmented Generation (RAG).
#
# Deux modes de recherche :
# - search()         : retourne des DocumentChunk[] triés par cosine distance,
#                      utilisé par OpenRouterService#build_rag_context pour
#                      injecter le contexte documentaire dans le prompt LLM.
# - search_documents() : retourne des documents uniques scorés, utilisé par
#                      la page de recherche UI (résultats affichés à l'user).
#
# Scoring hybride (search_documents uniquement) :
#   combined = 0.6 * vector_score + 0.3 * confirmed_full_text + 0.1 * title_boost
#   où confirmed_full_text = match tsvector ET match exact en clair (ILIKE)
#   (évite les faux positifs dus au stemming trop permissif du français)
#
# Seuils :
#   - Cosine distance < 0.35 (première barrière, filtrage vectoriel strict)
#   - combined >= 0.20 (deuxième filtre, score combiné)
class RagService
  # Distance cosinus max acceptée (1.0 = orthogonal, 0.0 = identique).
  # En dessous de 0.35 = suffisamment proche sémantiquement.
  COSINE_DISTANCE_THRESHOLD = 0.35

  # Score combiné minimum pour apparaître dans les résultats.
  RELEVANCE_FLOOR = 0.20

  # Pondérations du score hybride (somme = 1.0).
  WEIGHT_VECTOR = 0.6
  WEIGHT_TEXT = 0.3
  WEIGHT_TITLE = 0.1

  def initialize(user)
    @user = user
  end

  # Recherche les chunks de documents les plus pertinents.
  # Triés par cosine distance croissante, limités par `limit`.
  # Le caller (RAG chat) ne tient pas compte du score combiné.
  def search(query, folder_id: nil, document_id: nil, limit: 5)
    query_embedding = EmbeddingService.embed(query)
    return [] unless query_embedding

    vector_chunks = vector_search(query_embedding, folder_id: folder_id, document_id: document_id, limit: 50)
    vector_chunks
      .select { |c| cosine_distance(c) < COSINE_DISTANCE_THRESHOLD }
      .sort_by { |c| cosine_distance(c) }
      .first(limit)
  end

  # Recherche par documents uniques avec scoring hybride 60/30/10.
  # Retourne un tableau de Hash { document: Document, score: Float }.
  # Vide si aucun document ne passe les seuils.
  def search_documents(query, folder_id: nil, limit: 10)
    return [] if query.blank?

    query_embedding = EmbeddingService.embed(query)
    return [] unless query_embedding

    vector_chunks = vector_search(query_embedding, folder_id: folder_id, limit: 50)
    doc_vector_scores = best_vector_score_per_doc(vector_chunks)
    # Le bonus full-text ne s'applique que si le mot exact est aussi présent
    # en clair (titre ou content) — évite les faux positifs du stemming.
    confirmed_text_doc_ids = confirmed_text_matches(query, folder_id: folder_id)

    return [] if (doc_vector_scores.keys + confirmed_text_doc_ids).empty?

    score_and_rank(query, doc_vector_scores, confirmed_text_doc_ids, limit)
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

  private

  def best_vector_score_per_doc(chunks)
    scores = {}
    chunks.each do |chunk|
      next if cosine_distance(chunk) >= COSINE_DISTANCE_THRESHOLD

      score = 1.0 - cosine_distance(chunk)
      doc_id = chunk.document_id
      scores[doc_id] = score if score > (scores[doc_id] || 0.0)
    end
    scores
  end

  def score_and_rank(query, doc_vector_scores, text_doc_ids, limit)
    doc_ids = (doc_vector_scores.keys + text_doc_ids).uniq
    documents_by_id = Document.where(id: doc_ids).includes(:tags, :folder).index_by(&:id)
    query_down = query.downcase.strip

    scored = documents_by_id.values.map { |doc| score_document(doc, doc_vector_scores, text_doc_ids, query_down) }

    scored.select { |r| r[:score] >= RELEVANCE_FLOOR }
          .sort_by { |r| -r[:score] }
          .first(limit)
  end

  def score_document(doc, doc_vector_scores, text_doc_ids, query_down)
    v = doc_vector_scores[doc.id] || 0.0
    t = text_doc_ids.include?(doc.id) ? 1.0 : 0.0
    title_match = doc.title.to_s.downcase.include?(query_down) ? 1.0 : 0.0
    combined = (WEIGHT_VECTOR * v) + (WEIGHT_TEXT * t) + (WEIGHT_TITLE * title_match)
    { document: doc, score: combined }
  end

  def vector_search(query_embedding, folder_id:, limit:, document_id: nil)
    scope = DocumentChunk
            .joins(:document)
            .where(documents: { user_id: @user.id })

    scope = scope.where(document_id: document_id) if document_id
    scope = scope.where(documents: { folder_id: folder_id }) if folder_id && !document_id

    scope
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
      .includes(:document)
  end

  def full_text_doc_ids(query, folder_id:)
    return [] if query.blank?

    scope = Document.where(user_id: @user.id).full_text_search(query)
    scope = scope.where(folder_id: folder_id) if folder_id
    scope.pluck(:id)
  end

  # Match full-text confirmé par une présence exacte en clair (insensible à la casse).
  # Filtre les faux positifs où le stemming français fait matcher un mot qui n'a
  # rien à voir avec la query (ex: "franc-maçon" stem en "franc" pour "france").
  def confirmed_text_matches(query, folder_id:)
    text_ids = full_text_doc_ids(query, folder_id: folder_id)
    return [] if text_ids.empty?

    scope = Document.where(id: text_ids)
    scope = scope.where(folder_id: folder_id) if folder_id
    # sanitize_sql_like echappe les wildcards (% et _) saisis par l'utilisateur
    # pour eviter les faux-positifs (ex: "100%" qui matcherait "100" + n'importe quoi).
    safe = Document.sanitize_sql_like(query)
    scope
      .where("title ILIKE :q OR content ILIKE :q", q: "%#{safe}%")
      .pluck(:id)
  end

  def cosine_distance(chunk)
    chunk.neighbor_distance.to_f
  end
end
