class EspacesController < ApplicationController
  def index
    @folders = current_user.folders.where(parent_id: nil).includes(:documents, children: :documents)
    @sidebar_folders = current_user.folders.includes(:documents).to_a
    @documents_without_folder = current_user.documents.where(folder_id: nil)
  end
end
