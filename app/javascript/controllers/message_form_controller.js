import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  submitStart() {
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input")) // remet la hauteur à zéro
    this.submitTarget.disabled = true
    this.submitTarget.setAttribute("aria-busy", "true")
  }

  submitEnd() {
    // Réactivation en cas d'erreur réseau (succès = le frame est remplacé, bouton neuf)
    this.submitTarget.disabled = false
    this.submitTarget.removeAttribute("aria-busy")
  }
}
