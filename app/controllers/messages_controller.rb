class MessagesController < ApplicationController
  def create
    @conversation = current_user.conversations.find(params[:conversation_id])

    ActiveRecord::Base.transaction do
      @user_message = @conversation.messages.create!(role: "user", content: message_params[:content])

      # @conversation.update!(title: @user_message.content.truncate(50)) if @conversation.messages.where(role: "user").count == 1

      @ai_message = @conversation.messages.create!(role: "assistant", content: call_llm)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  rescue RubyLLM::Error, Faraday::Error => e
    Rails.logger.error "LLM Error: #{e.class} — #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    redirect_to conversation_path(@conversation), alert: "L'IA n'a pas pu répondre. Réessaie dans un instant.", status: :see_other
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def call_llm
    llm_conversation = RubyLLM.chat(model: "gpt-4.1-nano")
    llm_conversation.with_instructions(build_system_prompt)
    # TODO(branch: tools) — décommenter quand les tools seront définis
    # llm_conversation.with_tools(*available_tools) if available_tools.any?
    previous = @conversation.messages
                            .where(role: %w[user assistant])
                            .where.not(id: @user_message.id)
                            .order(:created_at)
                            .last(19)
    previous.each { |m| llm_conversation.add_message(role: m.role.to_sym, content: m.content) }
    llm_conversation.ask(@user_message.content).content
  end

  def build_system_prompt
    <<~PROMPT
      Tu es un assistant intelligent intégré à une application de gestion de connaissances personnelles.
      Tu as accès à une base documentaire vectorielle (PostgreSQL + pgvector) qui contient les documents et notes de l'utilisateur.

      Ton rôle est de répondre aux questions de l'utilisateur en t'appuyant prioritairement sur les documents retrouvés par recherche vectorielle sémantique.

      Règles à respecter :
      - Réponds toujours en te basant sur les documents pertinents fournis en contexte.
      - Si un document répond directement à la question, cite son contenu de façon précise.
      - Si aucun document pertinent n'est disponible, dis-le clairement avant de répondre avec tes connaissances générales.
      - Ne confonds jamais tes connaissances générales avec le contenu des documents de l'utilisateur.
      - Reste concis, structuré, et utile.
      - Réponds dans la même langue que l'utilisateur.
    PROMPT
  end

end
