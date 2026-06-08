import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["open"]
  static targets = ["chevron", "children", "node"]
  static values = { storageKey: { type: String, default: "mindsnap_sidebar_v1" } }

  connect() {
    this.openSet = this.loadState()
    this.restoreState()
  }

  toggle(event) {
    const node = event.currentTarget.closest("[data-folder-id]")
    if (!node) return

    const id = String(node.dataset.folderId)
    const isOpen = node.classList.toggle(this.openClass)

    this.updateAria(node, isOpen)

    if (isOpen) {
      this.openSet.add(id)
    } else {
      this.openSet.delete(id)
    }
    this.saveState()
  }

  expandAll() {
    this.nodeTargets.forEach((node) => {
      node.classList.add(this.openClass)
      this.updateAria(node, true)
    })
    this.openSet = new Set(this.nodeTargets.map((n) => n.dataset.folderId))
    this.saveState()
  }

  collapseAll() {
    this.nodeTargets.forEach((node) => {
      node.classList.remove(this.openClass)
      this.updateAria(node, false)
    })
    this.openSet = new Set()
    this.saveState()
  }

  restoreState() {
    this.nodeTargets.forEach((node) => {
      const id = node.dataset.folderId
      const isOpen = this.openSet.has(id)
      node.classList.toggle(this.openClass, isOpen)
      this.updateAria(node, isOpen)
    })
  }

  updateAria(node, isOpen) {
    const button = node.querySelector("[data-sidebar-tree-target='chevron']")
    if (button) button.setAttribute("aria-expanded", isOpen ? "true" : "false")
  }

  loadState() {
    try {
      const raw = localStorage.getItem(this.storageKeyValue)
      if (!raw) return new Set()
      const arr = JSON.parse(raw)
      return new Set(Array.isArray(arr) ? arr : [])
    } catch (e) {
      return new Set()
    }
  }

  saveState() {
    try {
      localStorage.setItem(this.storageKeyValue, JSON.stringify([...this.openSet]))
    } catch (e) {
      // localStorage indisponible (mode privé, quota) — silencieux
    }
  }
}
