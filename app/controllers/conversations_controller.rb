class ConversationsController < ApplicationController
  def index
    @conversations = current_user.conversations
  end

  def create
    @conversation = Conversation.new(conversation_params)
    @conversation.user = current_user

    if @conversation.save
      redirect_to conversation_path(@conversation)
    else
      render :new, status: :unprocessable_entity
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
