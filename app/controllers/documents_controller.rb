class DocumentsController < ApplicationController # rubocop:disable Metrics/ClassLength
  before_action :set_document, only: %i[show edit update destroy download summarize summary_status chat reset_chat]

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

  def show # rubocop:disable Metrics/MethodLength
    @folders = current_user.folders.where(parent_id: nil).includes(:documents, children: :documents)
    @sidebar_folders = current_user.folders.includes(:documents).to_a
    @documents_without_folder = current_user.documents.where(folder_id: nil)
    # Conversation doc-scopee (necessaire pour turbo_stream_from si l'offcanvas est ouvert)
    @doc_chat_conversation = current_user.conversations.find_or_create_by!(
      context_type: "Document", context_id: @document.id
    ) { |c| c.name = "Discussion — #{@document.title}" }
  end

  def chat
    @conversation = current_user.conversations.find_or_create_by!(
      context_type: "Document", context_id: @document.id
    ) { |c| c.name = "Discussion — #{@document.title}" }
    @messages = @conversation.messages.order(:created_at)
    @message = Message.new
    render partial: "documents/chat_panel",
           locals: { conversation: @conversation, messages: @messages, message: @message }
  end

  def reset_chat
    conversation = current_user.conversations.find_by(
      context_type: "Document", context_id: @document.id
    )
    conversation&.messages&.destroy_all
    conversation ||= current_user.conversations.create!(
      context_type: "Document", context_id: @document.id,
      name: "Discussion — #{@document.title}"
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "doc-chat-frame",
          partial: "documents/chat_panel",
          locals: { conversation: conversation, messages: [], message: Message.new }
        )
      end
      format.html { redirect_to @document, notice: "Discussion réinitialisée." }
    end
  end

  def download
    blob = ActiveStorage::Blob.find_signed!(params[:blob_signed_id])

    raise ActiveRecord::RecordNotFound unless @document.file.map { |a| a.blob.id }.include?(blob.id)

    if blob.service_name == "cloudinary"
      resource_type = cloudinary_resource_type(blob.content_type)
      public_id     = "#{Rails.env}/#{blob.key}"
      url = Cloudinary::Utils.cloudinary_url(
        public_id,
        resource_type: resource_type,
        type: "upload",
        flags: "attachment:#{File.basename(blob.filename.to_s, '.*').gsub(/[^a-zA-Z0-9_-]/, '_')}",
        secure: true
      )
      redirect_to url, allow_other_host: true
    else
      redirect_to rails_blob_url(blob, disposition: "attachment")
    end
  end

  def summarize
    if @document.content.blank?
      return redirect_to @document, alert: "Le document n'a pas de contenu à résumer." unless @document.file.attached?

      # Lancer l'extraction de texte qui chaînera → EmbedDocumentJob → SummarizeDocumentJob
      ExtractTextJob.perform_later(@document.id)
      return redirect_to @document, notice: "Extraction du texte en cours, le résumé suivra automatiquement…"

    end

    SummarizeDocumentJob.perform_later(@document.id)
    redirect_to @document, notice: "Résumé en cours de génération…"
  end

  def summary_status
    render json: { summary: @document.summary, content_present: @document.content.present? }
  end

  def edit
    return unless @document.document_type == "Lien" &&
                  @document.source_url.blank? &&
                  @document.content.present?

    @document.source_url = @document.content
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
    cloudinary_purge_files if Rails.env.production?
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
    params.require(:document).permit(:title, :content, :source_url, :document_type, :date_injection, file: [])
  end

  def cloudinary_purge_files
    @document.file.each do |attachment|
      key = "#{Rails.env}/#{attachment.blob.key}"
      %w[image raw video].each do |resource_type|
        Cloudinary::Uploader.destroy(key, resource_type: resource_type, invalidate: true)
      end
    end
  end

  def cloudinary_resource_type(content_type)
    case content_type
    when %r{\Aimage/}  then "image"
    when %r{\Avideo/}  then "video"
    when "application/pdf" then "image" # Cloudinary stocke les PDFs comme image
    else "raw"
    end
  end
end
