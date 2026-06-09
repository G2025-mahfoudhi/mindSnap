class DashboardController < ApplicationController
  def index
    @document_count = current_user.documents.count
    @document_limit = current_user.document_limit
    @recent_documents = current_user.documents.order(created_at: :desc).limit(5)
  end
end
