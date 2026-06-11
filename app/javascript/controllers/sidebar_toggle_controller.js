import { Controller } from "@hotwired/stimulus"

const MOBILE_BREAKPOINT = 768

export default class extends Controller {
  connect() {
    if (this.#isMobile()) {
      // Sur mobile : toujours replié au démarrage pour laisser la place au contenu
      this.element.classList.add("sidebar-collapsed")
      this.#syncIcon(true)
    } else if (localStorage.getItem("mindsnap_sidebar_collapsed") === "true") {
      this.element.classList.add("sidebar-collapsed")
      this.#syncIcon(true)
    }

    this._resizeHandler = this.#onResize.bind(this)
    window.addEventListener("resize", this._resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this._resizeHandler)
  }

  toggle() {
    const collapsed = this.element.classList.toggle("sidebar-collapsed")
    if (!this.#isMobile()) {
      localStorage.setItem("mindsnap_sidebar_collapsed", String(collapsed))
    }
    this.#syncIcon(collapsed)
  }

  #isMobile() {
    return window.innerWidth < MOBILE_BREAKPOINT
  }

  #onResize() {
    if (this.#isMobile()) {
      // En passant en mobile : replier si pas déjà replié
      if (!this.element.classList.contains("sidebar-collapsed")) {
        this.element.classList.add("sidebar-collapsed")
        this.#syncIcon(true)
      }
    } else {
      // En passant sur desktop : restaurer la préférence sauvegardée
      const saved = localStorage.getItem("mindsnap_sidebar_collapsed") === "true"
      this.element.classList.toggle("sidebar-collapsed", saved)
      this.#syncIcon(saved)
    }
  }

  #syncIcon(collapsed) {
    document.querySelectorAll("[data-sidebar-toggle-icon]").forEach(icon => {
      icon.className = collapsed ? "fa-solid fa-chevron-right" : "fa-solid fa-chevron-left"
    })
  }
}
