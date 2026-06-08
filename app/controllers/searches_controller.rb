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

    @results = perform_search
    @documents = @results.map { |r| r[:document] }
  end

  private

  def perform_search
    RagService.new(current_user).search_documents(@query, limit: RESULTS_LIMIT)
  rescue StandardError => e
    Rails.logger.error "Search error: #{e.class} — #{e.message}"
    flash.now[:alert] = "La recherche est momentanément indisponible."
    []
  end
end
