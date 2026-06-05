class DashboardController < ApplicationController
  DOCUMENT_LIMIT = 50

  def index
    @document_count = current_user.documents.count
    @document_limit = DOCUMENT_LIMIT
    @recent_documents = current_user.documents.order(created_at: :desc).limit(5)
  end
end
