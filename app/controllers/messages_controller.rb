class MessagesController < ApplicationController
  def create
    @conversation = current_user.conversations.find(params[:conversation_id])
    content = message_params[:content].to_s.strip

    if content.blank?
      respond_to do |format|
        format.turbo_stream { head :bad_request }
        format.html { redirect_to conversation_path(@conversation), alert: "Le message ne peut pas être vide." }
      end
      return
    end

    @user_message = @conversation.messages.create!(role: "user", content: content)
    maybe_update_title(content)

    begin
      ai_content = OpenRouterService.new(@conversation, @user_message).call
    rescue StandardError => e
      Rails.logger.error "OpenRouter Error: #{e.class} — #{e.message}"
      ai_content = "Désolé, je n'ai pas pu générer une réponse. Réessaie dans un instant."
    end

    @ai_message = @conversation.messages.create!(role: "assistant", content: ai_content)

    respond_to do |format|
      format.turbo_stream do
        template = params[:source] == "doc_chat" ? "messages/create_doc_chat" : "messages/create"
        render template
      end
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def maybe_update_title(content)
    return unless @conversation.name == "Nouvelle conversation"
    return unless @conversation.messages.where(role: "user").one?

    @conversation.update!(name: content.truncate(60))
    @title_updated = true
  end
end
