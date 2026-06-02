class FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_folder, only: [:show, :destroy]

  def index
    @folders = current_user.folders.where(parent_id: nil)
  end

  def show
    @children = @folder.children
    @documents = @folder.documents
  end

  def new
    @folder = Folder.new
  end

  def create
    @folder = current_user.folders.new(folder_params)

    if @folder.save
      redirect_to folders_path, notice: "Folder créé"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @folder.destroy
    redirect_to folders_path, notice: "Folder supprimé"
  end

  private

  def set_folder
    @folder = current_user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :parent_id)
  end
end
