class FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_folder, only: [:show, :edit, :update, :destroy]

  def index
    @folders = current_user.folders.where(parent_id: nil)
  end

  def show
    @children = @folder.children
    @documents = @folder.documents
    @folders = current_user.folders.where(parent_id: nil).includes(:documents)
    @documents_without_folder = current_user.documents.where(folder_id: nil)
  end

  def new
    @folder = Folder.new(parent_id: params[:parent_id])
  end

  def create
    @folder = current_user.folders.new(folder_params)

    if @folder.save
      destination = @folder.parent_id ? folder_path(@folder.parent_id) : espaces_path
      redirect_to destination, notice: "Dossier créé"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      redirect_to folder_path(@folder), notice: "Dossier modifié"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @folder.destroy
    redirect_to espaces_path, notice: "Dossier supprimé"
  end

  private

  def set_folder
    @folder = current_user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :parent_id)
  end
end
