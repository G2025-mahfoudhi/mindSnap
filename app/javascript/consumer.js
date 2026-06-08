// ActionCable consumer : point d'entrée unique pour toutes les connexions WebSocket.
// Chaque conversation cote client s'abonne via ConversationChannel.
import { createConsumer } from "@rails/actioncable"

export default createConsumer()
