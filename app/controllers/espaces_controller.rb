class EspacesController < ApplicationController
  def index
    @folders = current_user.folders.where(parent_id: nil).includes(:documents, children: :documents)
    @documents_without_folder = current_user.documents.where(folder_id: nil)
  end
end