// Canal de streaming par conversation.
// Chaque client s'abonne a `conversation_#{id}` et recoit les turbo_stream
// de remplacement de messages (utilise par les broadcasts du job streaming).
import consumer from "consumer"

consumer.subscriptions.create(
  { channel: "ConversationChannel", conversation_id: window.location.pathname.split("/").pop() },
  {
    connected() {
      // Subscription OK
    },
    received(data) {
      // Le data est un fragment HTML turbo_stream (turbo_stream.replace).
      // Turbo l'intercepte et remplace le DOM cible.
      if (data.html) {
        Turbo.renderStreamMessage(data.html)
      }
    }
  }
)
