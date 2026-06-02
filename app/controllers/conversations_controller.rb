class ConversationsController < ApplicationController
  def index
    @conversations = current_user.conversations
  end

  def create
    @conversation = current_user.conversations.build(
      name: params.dig(:conversation, :name).presence || "Conversation du #{Time.current.strftime('%d/%m à %H:%M')}"
    )
    if @conversation.save
      redirect_to conversation_path(@conversation)
    else
      redirect_to conversations_path, alert: "Impossible de créer la conversation."
    end
  end

  def show
    @conversation = current_user.conversations.find(params[:id])
    @messages = @conversation.messages.order(:created_at)
    @message  = Message.new
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
