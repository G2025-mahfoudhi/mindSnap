class DocumentsController < ApplicationController # rubocop:disable Metrics/ClassLength
  before_action :set_document,
                only: %i[show edit update destroy download summarize summary_status chat reset_chat assign_folder remove_file split_to_folder]

  def index
    @documents = current_user.documents.order(created_at: :desc)
  end

  def new
    @document = current_user.documents.build(date_injection: Time.current, folder_id: params[:folder_id])
  end

  def create
    @document = current_user.documents.build(document_params)
    @document.folder = resolve_folder
    @document.date_injection ||= Time.current
    if @document.save
      redirect_to document_path(@document), notice: "Document créé avec succès.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @folders = current_user.folders.where(parent_id: nil).includes(:documents, children: :documents)
    @sidebar_folders = current_user.folders.includes(:documents).to_a
    @suggest_folders = current_user.folders.includes(:parent).order(:name).to_a
    @documents_without_folder = current_user.documents.where(folder_id: nil)
    # Conversation doc-scopée : lecture seule, créée seulement si elle existe déjà.
    # La création se fait à la demande dans l'action `chat` (clic sur "Discuter").
    @doc_chat_conversation = current_user.conversations.find_by(
      context_type: "Document", context_id: @document.id
    )
  end

  def chat
    @conversation = current_user.conversations.find_or_create_by!(
      context_type: "Document", context_id: @document.id
    ) { |c| c.name = "Discussion — #{@document.title}" }
    @messages = @conversation.messages.order(:created_at)
    @message = Message.new
    @suggest_folders = current_user.folders.includes(:parent).order(:name).to_a
    render partial: "documents/chat_panel",
           locals: { conversation: @conversation, messages: @messages, message: @message,
                     document: @document, suggest_folders: @suggest_folders }
  end

  def reset_chat # rubocop:disable Metrics/MethodLength
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
          locals: { conversation: conversation, messages: [], message: Message.new,
                    document: @document, suggest_folders: @suggest_folders }
        )
      end
      format.html { redirect_to document_path(@document), notice: "Discussion réinitialisée." }
    end
  end

  def download # rubocop:disable Metrics/MethodLength
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
      redirect_to rails_blob_url(blob, disposition: "attachment"), allow_other_host: true
    end
  end

  def summarize # rubocop:disable Metrics/MethodLength
    return redirect_to document_path(@document), alert: "Le document n'a pas de contenu à résumer." if
      @document.content.blank? && !@document.file.attached?

    @document.update_columns(summary: nil)
    enqueue_summarize_job

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "doc-summary-content",
          partial: "documents/summary_regenerating"
        )
      end
      format.html { redirect_to document_path(@document), notice: "Résumé en cours de génération…" }
    end
  end

  def summary_status
    render json: { summary: @document.summary, content_present: @document.content.present? }
  end

  def assign_folder
    folder = current_user.folders.find(params[:folder_id])
    @document.update!(folder: folder)
    redirect_back fallback_location: document_path(@document),
                  notice: "Document classé dans « #{folder.name} ».",
                  status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: document_path(@document),
                  alert: "Dossier introuvable.",
                  status: :see_other
  end

  def edit
    @return_to = safe_return_to(params[:return_to])
    return unless @document.document_type == "Lien" &&
                  @document.source_url.blank? &&
                  @document.content.present?

    @document.source_url = @document.content
  end

  def update
    @document.folder = resolve_folder
    if @document.update(document_params_without_file)
      attach_new_files_and_reindex
      destination = safe_return_to(params[:return_to]) || document_path(@document)
      redirect_to destination, notice: "Document mis à jour.", status: :see_other
    else
      @return_to = safe_return_to(params[:return_to])
      render :edit, status: :unprocessable_entity
    end
  end

  def split_to_folder # rubocop:disable Metrics/MethodLength
    @attachment = @document.file.find(params[:attachment_id])
    @folder     = current_user.folders.find(params[:folder_id])
    @new_doc    = extract_file_to_folder(@attachment, @folder)

    @document.reload
    @sidebar_folders          = current_user.folders.includes(:documents).to_a
    @documents_without_folder = current_user.documents.where(folder_id: nil)
    @suggest_folders          = current_user.folders.includes(:parent).order(:name).to_a

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to document_path(@document),
                    notice: "« #{@attachment.blob.filename} » extrait dans « #{@folder.name} ».",
                    status: :see_other
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to document_path(@document), alert: "Dossier introuvable.", status: :see_other
  end

  def remove_file
    attachment = @document.file.find(params[:attachment_id])
    cloudinary_purge_attachment(attachment) if Rails.env.production?
    attachment.purge
    @document.update_columns(content: nil, summary: nil)
    ExtractTextJob.perform_later(@document.id) if @document.file.attached?
    redirect_to document_path(@document), notice: "Fichier supprimé.", status: :see_other
  end

  def destroy
    folder = @document.folder
    cloudinary_purge_files if Rails.env.production?
    @document.destroy
    destination = safe_return_to(params[:return_to]) || (folder ? folder_path(folder) : espaces_path)
    redirect_to destination, notice: "Document supprimé.", status: :see_other
  end

  private

  def set_document
    scope = current_user.documents.includes(file_attachments: :blob)
    @document = scope.find(params[:id])
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

  def extract_file_to_folder(attachment, folder)
    new_doc = current_user.documents.create!(
      title: File.basename(attachment.blob.filename.to_s, ".*").gsub(/[_-]+/, " ").strip,
      document_type: "Fichier",
      folder: folder,
      date_injection: Time.current
    )
    new_doc.file.attach(attachment.blob)
    # `delete` supprime uniquement l'enregistrement ActiveStorage::Attachment
    # sans déclencher la purge du blob (qui est maintenant utilisé par new_doc).
    attachment.delete
    @document.update_columns(content: nil, summary: nil)
    ExtractTextJob.perform_later(@document.id) if @document.file.reload.attached?
    ExtractTextJob.perform_later(new_doc.id)
    new_doc
  end

  def enqueue_summarize_job
    if @document.file.attached?
      ExtractTextJob.perform_later(@document.id)
    else
      token = SecureRandom.hex(8)
      Rails.cache.write("summarize_token_#{@document.id}", token, expires_in: 15.minutes)
      SummarizeDocumentJob.perform_later(@document.id, token)
    end
  end

  def document_params_without_file
    params.require(:document).permit(:title, :content, :source_url, :document_type, :date_injection)
  end

  def attach_new_files_and_reindex
    new_files = params.dig(:document, :file)&.reject(&:blank?)
    return unless new_files.present?

    @document.file.attach(new_files)
    @document.update_columns(content: nil, summary: nil)
    ExtractTextJob.perform_later(@document.id)
  end

  def cloudinary_purge_files
    @document.file.each { |a| cloudinary_purge_attachment(a) }
  end

  def cloudinary_purge_attachment(attachment)
    key = "#{Rails.env}/#{attachment.blob.key}"
    %w[image raw video].each do |resource_type|
      Cloudinary::Uploader.destroy(key, resource_type: resource_type, invalidate: true)
    rescue StandardError => e
      Rails.logger.warn "cloudinary_purge_attachment: #{e.message}"
    end
  end

  def safe_return_to(path)
    return nil unless path.present?

    uri = URI.parse(path)
    uri.host.nil? ? path : nil
  rescue URI::InvalidURIError
    nil
  end

  def cloudinary_resource_type(content_type)
    case content_type
    when %r{\Aimage/}  then "image"
    when %r{\Avideo/}  then "video"
    when "application/pdf" then "image" # rubocop:disable Lint/DuplicateBranch
    else "raw"
    end
  end
end
