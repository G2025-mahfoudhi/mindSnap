import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = {
    documentId: Number,
    hasSummary: Boolean
  }

  connect() {
    if (this.hasSummaryValue) return

    this.attempts = 0
    this.maxAttempts = 20
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.timer = setInterval(() => this.check(), 3000)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async check() {
    this.attempts++
    if (this.attempts > this.maxAttempts) {
      this.stopPolling()
      this.contentTarget.innerHTML = `<p class="text-muted fst-italic mb-0">La génération du résumé prend plus de temps que prévu. <a href="javascript:location.reload()">Actualiser la page</a> ou réessayer dans quelques instants.</p>`
      return
    }

    try {
      const url = `/documents/${this.documentIdValue}/summary_status`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      if (data.summary) {
        this.updateContent(data.summary)
        this.stopPolling()
      }
    } catch {
      // réseau ou parse — on réessaie au prochain tick
    }
  }

  updateContent(text) {
    const paragraphs = text.split(/\n{2,}/).filter(p => p.trim())
    const html = paragraphs
      .map(p => `<p>${this.escapeHtml(p.trim())}</p>`)
      .join("")

    this.contentTarget.innerHTML = html
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML.replace(/\n/g, "<br>")
  }
}
