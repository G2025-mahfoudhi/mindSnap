# Diffuse les Turbo Stream de remplacement de messages pour une conversation donnee.
# Les clients abonnes recoivent chaque chunk de l'IA en temps reel et Turbo
# remplace le DOM de la bulle assistant.
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = current_user.conversations.find_by(id: params[:conversation_id])
    return reject unless conversation

    stream_from "conversation_#{conversation.id}"
  end

  def unsubscribed
    # cleanup si necessaire
  end
end
