class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy download]

  def index
    @documents = current_user.documents.where(folder_id: nil)
  end

  def new
    @document = current_user.documents.build(date_injection: Time.current, folder_id: params[:folder_id])
  end

  def create
    @document = current_user.documents.build(document_params)
    @document.folder = resolve_folder
    @document.date_injection ||= Time.current
    if @document.save
      redirect_to @document, notice: "Document créé avec succès.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @folders = current_user.folders.where(parent_id: nil).includes(:documents, children: :documents)
    @sidebar_folders = current_user.folders.includes(:documents).to_a
    @documents_without_folder = current_user.documents.where(folder_id: nil)
  end

  def download
    blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])

    unless @document.file.map { |a| a.blob.id }.include?(blob.id)
      raise ActiveRecord::RecordNotFound
    end

    # On télécharge via Rails (credentials serveur) pour contourner les restrictions
    # d'accès public sur Cloudinary (Strict Transformations activé sur le compte).
    send_data blob.download,
              filename: blob.filename.to_s,
              type: blob.content_type,
              disposition: "attachment"
  end

  def edit
  end

  def update
    @document.folder = resolve_folder
    if @document.update(document_params)
      redirect_to @document, notice: "Document mis à jour.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    folder = @document.folder
    @document.destroy
    destination = folder ? folder_path(folder) : espaces_path
    redirect_to destination, notice: "Document supprimé.", status: :see_other
  end

  private

  def set_document
    @document = current_user.documents.find(params[:id])
  end

  def resolve_folder
    folder_id = params.dig(:document, :folder_id)
    if folder_id == "new"
      name = params[:new_folder_name].presence
      current_user.folders.create(name: name) if name
    elsif folder_id.present?
      current_user.folders.find_by(id: folder_id)
    end
  end

  def document_params
    params.require(:document).permit(:title, :content, :document_type, :date_injection, file: [])
  end
end
