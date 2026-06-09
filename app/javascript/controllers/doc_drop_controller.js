import { Controller } from "@hotwired/stimulus"

// Drag-and-drop for classifying documents into folders.
// Put data-controller="doc-drop" on any container that contains:
//   - draggable elements: [data-document-id] with draggable="true"
//   - drop zones:         [data-folder-id]  (any real folder, not "__no_folder__")
export default class extends Controller {
  connect() {
    this._handlers = {
      dragstart: this.#onDragStart.bind(this),
      dragover:  this.#onDragOver.bind(this),
      dragleave: this.#onDragLeave.bind(this),
      drop:      this.#onDrop.bind(this),
      dragend:   this.#onDragEnd.bind(this)
    }
    for (const [event, handler] of Object.entries(this._handlers)) {
      this.element.addEventListener(event, handler)
    }
  }

  disconnect() {
    for (const [event, handler] of Object.entries(this._handlers || {})) {
      this.element.removeEventListener(event, handler)
    }
  }

  #onDragStart(e) {
    const doc = e.target.closest("[data-document-id]")
    if (!doc) return
    e.dataTransfer.setData("text/plain", doc.dataset.documentId)
    e.dataTransfer.effectAllowed = "move"
    doc.classList.add("doc-dragging")
  }

  #onDragOver(e) {
    const folder = this.#validFolderTarget(e.target)
    if (!folder) return
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"
    folder.classList.add("doc-drop-target")
  }

  #onDragLeave(e) {
    const folder = this.#validFolderTarget(e.target)
    if (!folder) return
    if (folder.contains(e.relatedTarget)) return
    folder.classList.remove("doc-drop-target")
  }

  #onDrop(e) {
    const folder = this.#validFolderTarget(e.target)
    if (!folder) return
    e.preventDefault()
    folder.classList.remove("doc-drop-target")

    const documentId = e.dataTransfer.getData("text/plain")
    if (!documentId) return

    this.#submit(documentId, folder.dataset.folderId)
  }

  #onDragEnd(e) {
    const doc = e.target.closest("[data-document-id]")
    if (doc) doc.classList.remove("doc-dragging")
    this.element.querySelectorAll(".doc-drop-target").forEach(el => el.classList.remove("doc-drop-target"))
  }

  #validFolderTarget(target) {
    const folder = target.closest("[data-folder-id]")
    if (!folder || folder.dataset.folderId === "__no_folder__") return null
    return folder
  }

  #submit(documentId, folderId) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = `/documents/${documentId}/assign_folder`
    form.appendChild(this.#hidden("_method", "patch"))
    form.appendChild(this.#hidden("folder_id", folderId))
    form.appendChild(this.#hidden("authenticity_token",
      document.querySelector('meta[name="csrf-token"]')?.content || ""))
    document.body.appendChild(form)
    form.requestSubmit()
    form.remove()
  }

  #hidden(name, value) {
    const el = document.createElement("input")
    el.type = "hidden"
    el.name = name
    el.value = value
    return el
  }
}
