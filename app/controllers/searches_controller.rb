# Contrôleur de recherche intelligente.
# Utilise RagService.search_documents qui combine :
# - similarité vectorielle (cosine sur embeddings pgvector)
# - recherche full-text PostgreSQL (tsvector)
# - boost titre
# Affiche les résultats triés par score avec badge de pertinence.
class SearchesController < ApplicationController
  RESULTS_LIMIT = 10

  def index
    @query = params[:q]
    return if @query.blank?

    begin
      rag = RagService.new(current_user)
      @results = rag.search_documents(@query, limit: RESULTS_LIMIT)
      @documents = @results.map { |r| r[:document] }
    rescue StandardError => e
      Rails.logger.error "Search error: #{e.class} — #{e.message}"
      @results = []
      @documents = []
      flash.now[:alert] = "La recherche est momentanément indisponible."
    end
  end
end
