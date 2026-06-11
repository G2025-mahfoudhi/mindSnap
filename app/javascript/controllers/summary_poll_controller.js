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
        if (data.content_present) this.revealDocSection()
      }
    } catch {
      // réseau ou parse — on réessaie au prochain tick
    }
  }

  revealDocSection() {
    const section = document.getElementById("doc-content-section")
    if (section) section.classList.remove("d-none")
  }

  updateContent(text) {
    this.contentTarget.innerHTML =
      `<div class="markdown-content">${this.renderMarkdown(text)}</div>`
  }

  renderMarkdown(text) {
    return text
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>")
      .replace(/`(.+?)`/g, "<code>$1</code>")
      .replace(/^#{3}\s+(.+)$/gm, "<h4>$1</h4>")
      .replace(/^#{2}\s+(.+)$/gm, "<h3>$1</h3>")
      .replace(/^#{1}\s+(.+)$/gm, "<h2>$1</h2>")
      .replace(/^[-*]\s+(.+)$/gm, "<li>$1</li>")
      .replace(/(<li>.*<\/li>)/s, "<ul>$1</ul>")
      .replace(/\n{2,}/g, "</p><p>")
      .replace(/\n/g, "<br>")
      .replace(/^(?!<)(.+)/, "<p>$1")
      .replace(/([^>])$/, "$1</p>")
  }
}
