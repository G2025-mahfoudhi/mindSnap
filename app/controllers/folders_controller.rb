class FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_folder, only: [:show, :destroy]

  def index
    @folders = [] # temporaire, en attendant le modèle
  end

  def show
    # temporaire
  end

  def new
    @folder = nil  # temporaire
  end

  def create
    # temporaire
    redirect_to folders_path
  end

  def destroy
    # temporaire
    redirect_to folders_path
  end

  private

  def set_folder
    # temporaire
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :parent_id)
  end
end
