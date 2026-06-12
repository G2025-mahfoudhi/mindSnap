import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { messagesId: { type: String, default: "messages" } }

  connect() {
    this._observer = new MutationObserver(() => this.#syncLock())
    const container = document.getElementById(this.messagesIdValue)
    if (container) {
      this._observer.observe(container, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ["data-streaming"]
      })
    }
    // Verrouille immédiatement si un message est déjà en cours de streaming
    this.#syncLock()
  }

  disconnect() {
    this._observer?.disconnect()
  }

  submitStart() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.dispatchEvent(new Event("input"))
    }
    this.#lock()
  }

  submitEnd() {
    // Cas d'erreur réseau : réactiver si aucun streaming en cours
    // (succès = le frame est remplacé par un nouveau formulaire)
    if (!this.#isStreaming()) this.#unlock()
  }

  #syncLock() {
    this.#isStreaming() ? this.#lock() : this.#unlock()
  }

  #isStreaming() {
    const container = document.getElementById(this.messagesIdValue)
    return !!container?.querySelector("[data-streaming='true']")
  }

  #lock() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = true
    this.submitTarget.setAttribute("aria-busy", "true")
  }

  #unlock() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = false
    this.submitTarget.removeAttribute("aria-busy")
  }
}
