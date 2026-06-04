# Contrôleur de recherche sémantique unifiée.
# Transforme la requête en embedding, cherche les documents les plus
# pertinents via RagService (pgvector nearest_neighbors), et affiche
# les résultats avec leurs tags et résumés.
class SearchesController < ApplicationController
  def index
    @query = params[:q]

    return unless @query.present?

    begin
      rag = RagService.new(current_user)
      @chunks = rag.search(@query, limit: 20)
      @documents = Document
                   .where(id: @chunks.map(&:document_id).uniq)
                   .includes(:tags, :folder)
    rescue StandardError => e
      Rails.logger.error "Search error: #{e.class} — #{e.message}"
      @chunks = []
      @documents = []
      flash.now[:alert] = "La recherche est momentanément indisponible."
    end
  end
end
