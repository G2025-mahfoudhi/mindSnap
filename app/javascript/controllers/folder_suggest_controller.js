import { Controller } from "@hotwired/stimulus"

// Scans message/summary containers for AI folder suggestions (📁 Dossier suggéré : Name)
// and injects a one-click "Ranger dans" button next to each one.
// Works with streamed content via MutationObserver.
export default class extends Controller {
  static values = {
    documentId: Number,
    folders: Array   // [{ id: 1, name: "Informatique" }, ...]
  }

  connect() {
    this.observer = new MutationObserver(() => this.#scheduleReScan())
    this.#startObserving()
    this.scan()
  }

  disconnect() {
    this.observer.disconnect()
    clearTimeout(this._scanTimer)
  }

  scan() {
    if (!this.documentIdValue) return

    this.observer.disconnect()

    // Remove any previously injected buttons before re-scanning
    this.element.querySelectorAll(".folder-suggest-btn").forEach(el => el.remove())

    this.element.querySelectorAll(".markdown-content p, .doc-show-content p").forEach(p => {
      if (!p.textContent.includes("📁") || !p.textContent.includes("Dossier suggéré")) return

      const match = p.textContent.match(/📁.*?Dossier suggéré\s*:\s*(.+?)\s*$/im)
      if (!match) return

      const folderName = match[1].replace(/\*+/g, "").trim()
      const folder = this.foldersValue.find(
        f => f.name.trim().toLowerCase() === folderName.toLowerCase()
      )
      if (!folder) return

      p.insertAdjacentElement("afterend", this.#buildForm(folder))
    })

    this.#startObserving()
  }

  #scheduleReScan() {
    clearTimeout(this._scanTimer)
    this._scanTimer = setTimeout(() => this.scan(), 150)
  }

  #startObserving() {
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  #buildForm(folder) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = `/documents/${this.documentIdValue}/assign_folder`
    form.className = "folder-suggest-btn d-inline-block mt-1"

    form.appendChild(this.#hidden("_method", "patch"))
    form.appendChild(this.#hidden("folder_id", folder.id))
    form.appendChild(this.#hidden("authenticity_token", this.#csrfToken()))

    const btn = document.createElement("button")
    btn.type = "submit"
    btn.className = "btn btn-sm btn-outline-success"
    btn.innerHTML = `<i class="fa-solid fa-folder-plus me-1"></i>Ranger dans « ${folder.name} »`

    form.addEventListener("submit", (e) => {
      if (!confirm(`Classer ce document dans « ${folder.name} » ?`)) e.preventDefault()
    })

    form.appendChild(btn)
    return form
  }

  #hidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
  }

  #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") || ""
  }
}
