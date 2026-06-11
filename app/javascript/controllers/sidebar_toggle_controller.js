import { Controller } from "@hotwired/stimulus"

const MOBILE_BREAKPOINT = 768
const KEY_DESKTOP = "mindsnap_sidebar_collapsed"
const KEY_MOBILE  = "mindsnap_sidebar_collapsed_mobile"

export default class extends Controller {
  connect() {
    // Restaure l'état sauvegardé (mobile et desktop séparés)
    // Premier accès mobile → replié par défaut (null != "false")
    const collapsed = this.#isMobile()
      ? localStorage.getItem(KEY_MOBILE) !== "false"
      : localStorage.getItem(KEY_DESKTOP) === "true"

    this.element.classList.toggle("sidebar-collapsed", collapsed)
    this.#syncIcon(collapsed)

    this._resizeHandler = this.#onResize.bind(this)
    window.addEventListener("resize", this._resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this._resizeHandler)
  }

  toggle() {
    const collapsed = this.element.classList.toggle("sidebar-collapsed")
    localStorage.setItem(this.#isMobile() ? KEY_MOBILE : KEY_DESKTOP, String(collapsed))
    this.#syncIcon(collapsed)
  }

  #isMobile() {
    return window.innerWidth < MOBILE_BREAKPOINT
  }

  #onResize() {
    const collapsed = this.#isMobile()
      ? localStorage.getItem(KEY_MOBILE) !== "false"
      : localStorage.getItem(KEY_DESKTOP) === "true"

    this.element.classList.toggle("sidebar-collapsed", collapsed)
    this.#syncIcon(collapsed)
  }

  #syncIcon(collapsed) {
    document.querySelectorAll("[data-sidebar-toggle-icon]").forEach(icon => {
      icon.className = collapsed ? "fa-solid fa-chevron-right" : "fa-solid fa-chevron-left"
    })
  }
}
