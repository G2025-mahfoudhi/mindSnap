import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (localStorage.getItem("mindsnap_sidebar_collapsed") === "true") {
      this.element.classList.add("sidebar-collapsed")
      this.#syncIcon(true)
    }
  }

  toggle() {
    const collapsed = this.element.classList.toggle("sidebar-collapsed")
    localStorage.setItem("mindsnap_sidebar_collapsed", String(collapsed))
    this.#syncIcon(collapsed)
  }

  #syncIcon(collapsed) {
    document.querySelectorAll("[data-sidebar-toggle-icon]").forEach(icon => {
      icon.className = collapsed ? "fa-solid fa-chevron-right" : "fa-solid fa-chevron-left"
    })
  }
}
