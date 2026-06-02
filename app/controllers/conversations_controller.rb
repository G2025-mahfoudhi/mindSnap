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

  private

  def conversation_params
    params.require(:conversation).permit(:name)
  end
end
