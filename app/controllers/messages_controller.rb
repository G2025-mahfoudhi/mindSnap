class MessagesController < ApplicationController
  def create
    @conversation = current_user.conversations.find(params[:conversation_id])
    @user_message = @conversation.messages.create!(role: "user", content: message_params[:content])

    begin
      ai_content = OpenRouterService.new(@conversation, @user_message).call
    rescue => e
      Rails.logger.error "OpenRouter Error: #{e.class} — #{e.message}"
      ai_content = "Désolé, je n'ai pas pu générer une réponse. Réessaie dans un instant."
    end

    @ai_message = @conversation.messages.create!(role: "assistant", content: ai_content)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
