class MessagesController < ApplicationController
  def create # rubocop:disable Metrics/MethodLength
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

    # Streaming : on cree le ai_message VIDE (streaming: true), on enqueue le
    # job qui va le remplir token par token et broadcaster chaque batch.
    @ai_message = @conversation.messages.create!(role: "assistant", content: "", streaming: true)
    StreamAiResponseJob.perform_later(@ai_message.id)

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
end
