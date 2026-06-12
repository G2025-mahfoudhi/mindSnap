class ConversationsController < ApplicationController
  def index
    @conversations = current_user.conversations.general.order(created_at: :desc)
  end

  def create
    @conversation = current_user.conversations.build(
      name: params.dig(:conversation, :name).presence || "Nouvelle conversation"
    )
    if @conversation.save
      redirect_to conversation_path(@conversation)
    else
      redirect_to conversations_path, alert: "Impossible de créer la conversation."
    end
  end

  def show
    @conversation = current_user.conversations.find(params[:id])
    @conversations = current_user.conversations.general.order(created_at: :desc)
    @messages = @conversation.messages.order(:created_at)
    @message  = Message.new
    return unless @conversation.context_type == "Document"

    @suggest_document = current_user.documents.find_by(id: @conversation.context_id)
    @suggest_folders  = current_user.folders.includes(:parent).order(:name).to_a
  end

  def destroy
    @conversation = current_user.conversations.find(params[:id])
    @conversation.destroy
    redirect_to conversations_path, notice: "Conversation supprimée.", status: :see_other
  end

  private

  def conversation_params
    params.require(:conversation).permit(:name)
  end
end
