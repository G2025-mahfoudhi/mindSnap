import { Controller } from "@hotwired/stimulus"
import { Swal, buildOptions } from "confirm"

// Scans message/summary containers for AI folder suggestions (📁 Dossier suggéré : Name)
// and injects a one-click "Ranger dans" button next to each one.
// Works with streamed content via MutationObserver.
export default class extends Controller {
  static values = {
    documentId: Number,
    folders: Array,       // [{ id: 1, name: "Informatique" }, ...]
    attachments: Array    // [{ id: 12, filename: "rapport.pdf" }, ...] — ordre = Fichier N
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

    this.element.querySelectorAll(".folder-suggest-btn").forEach(el => el.remove())

    const seenFolderIds = new Set()

    this.element.querySelectorAll(".markdown-content p, .doc-show-content p").forEach(p => {
      const text = p.textContent

      // Séparation suggérée
      if (text.includes("✂️") && text.includes("Séparation")) {
        const match = text.match(/✂️.*?[Ss]éparation[^:]*:\s*(.+?)\s*$/im)
        if (match && !p.nextElementSibling?.classList.contains("folder-suggest-btn")) {
          p.insertAdjacentElement("afterend", this.#buildSeparationNote(match[1].replace(/\*+/g, "").trim()))
        }
        return
      }

      // Dossier suggéré
      if (!text.includes("📁")) return
      const match = text.match(/📁[^:]*:\s*(.+?)\s*$/im)
      if (!match) return

      const folderName = match[1].replace(/\*+/g, "").replace(/[.,;:!?]$/, "").trim()
      const folder = this.foldersValue.find(
        f => f.name.trim().toLowerCase() === folderName.toLowerCase()
      )
      if (!folder || seenFolderIds.has(folder.id)) return

      seenFolderIds.add(folder.id)
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

    const confirmAndSubmit = async (e) => {
      e.preventDefault()
      const { isConfirmed } = await Swal.fire(buildOptions(`Classer ce document dans « ${folder.name} » ?`))
      if (isConfirmed) {
        form.removeEventListener("submit", confirmAndSubmit)
        form.requestSubmit()
      }
    }
    form.addEventListener("submit", confirmAndSubmit)

    form.appendChild(btn)
    return form
  }

  #buildSeparationNote(text) {
    const div = document.createElement("div")
    div.className = "folder-suggest-btn alert alert-warning p-2 mt-2"
    div.style.fontSize = "0.85rem"

    const header = document.createElement("div")
    header.className = "d-flex align-items-start gap-2 mb-2"
    header.innerHTML = `<i class="fa-solid fa-scissors mt-1 flex-shrink-0"></i><span><strong>Séparation suggérée :</strong> ${text}</span>`
    div.appendChild(header)

    const buttons = document.createElement("div")
    buttons.className = "d-flex flex-wrap gap-2"

    const seenIds = new Set()
    text.split(/[,\n]+/).forEach(segment => {
      // Format attendu : "Fichier N → NomDossier" ou "Fichier N → NomDossier"
      const fileMatch = segment.match(/fichier\s+(\d+)/i)
      const fileIndex = fileMatch ? parseInt(fileMatch[1], 10) - 1 : null
      const attachment = fileIndex !== null ? (this.attachmentsValue[fileIndex] || null) : null

      const candidate = segment.replace(/fichier\s+\d+/gi, "").replace(/→|>/g, "").replace(/\*+/g, "").trim()
      const folder = this.foldersValue.find(f => f.name.trim().toLowerCase() === candidate.toLowerCase())
      if (!folder || seenIds.has(folder.id)) return
      seenIds.add(folder.id)

      buttons.appendChild(attachment
        ? this.#buildSplitForm(folder, attachment)
        : this.#buildForm(folder))
    })

    if (buttons.children.length > 0) div.appendChild(buttons)
    return div
  }

  #buildSplitForm(folder, attachment) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = `/documents/${this.documentIdValue}/split_to_folder`
    form.className = "folder-suggest-btn d-inline-block mt-1"

    form.appendChild(this.#hidden("authenticity_token", this.#csrfToken()))
    form.appendChild(this.#hidden("folder_id", folder.id))
    form.appendChild(this.#hidden("attachment_id", attachment.id))

    const btn = document.createElement("button")
    btn.type = "submit"
    btn.className = "btn btn-sm btn-outline-warning"
    btn.innerHTML = `<i class="fa-solid fa-file-export me-1"></i>Extraire « ${attachment.filename} » → ${folder.name}`

    const confirmAndSubmit = async (e) => {
      e.preventDefault()
      const msg = `Extraire « ${attachment.filename} » dans le dossier « ${folder.name} » et le retirer de ce document ?`
      const { isConfirmed } = await Swal.fire(buildOptions(msg))
      if (isConfirmed) {
        form.removeEventListener("submit", confirmAndSubmit)
        form.requestSubmit()
      }
    }
    form.addEventListener("submit", confirmAndSubmit)
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
