import { Controller } from "@hotwired/stimulus"

// Auto-scroll vers le bas au chargement initial et a chaque mutation de la
// liste de messages (ajout OU modification de contenu d'un message existant,
// comme lors d'un streaming IA).
export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver((mutations) => {
      // Scroll a chaque mutation : ajout (childList) OU mise a jour de
      // contenu (characterData) lors d'un streaming Turbo Stream.
      this.scrollToBottom()
    })
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      characterData: true
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
