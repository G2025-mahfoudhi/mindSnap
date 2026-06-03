class SearchesController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      rag = RagService.new(current_user)
      @chunks = rag.search(@query, limit: 20)
      @documents = Document
        .where(id: @chunks.map(&:document_id).uniq)
        .includes(:tags, :folder)
    end
  end
end
