import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "doc_chat_width"
const MIN_WIDTH    = 320
const MAX_RATIO    = 0.92   // max 92 vw

export default class extends Controller {
  static targets = ["frame"]
  static values  = { url: String }

  // ——— Lifecycle ———

  connect() {
    this._onShow = this.load.bind(this)
    this.element.addEventListener("show.bs.offcanvas", this._onShow)
    this._restoreWidth()
    this._injectHandle()
  }

  disconnect() {
    this.element.removeEventListener("show.bs.offcanvas", this._onShow)
    this._stopResize()
  }

  // ——— Lazy-load the chat frame ———

  load() {
    if (!this.frameTarget.getAttribute("src")) {
      this.frameTarget.setAttribute("src", this.urlValue)
    }
  }

  // ——— Resize ———

  startResize(e) {
    if (e.button !== 0) return   // left click only
    e.preventDefault()
    this._startX     = e.clientX
    this._startWidth = this.element.offsetWidth

    this._boundMove = this._doResize.bind(this)
    this._boundUp   = this._stopResize.bind(this)
    document.addEventListener("mousemove", this._boundMove)
    document.addEventListener("mouseup",   this._boundUp)
    document.body.style.userSelect = "none"
    document.body.style.cursor     = "ew-resize"
  }

  _doResize(e) {
    const delta    = this._startX - e.clientX           // drag left → wider
    const maxWidth = window.innerWidth * MAX_RATIO
    const newWidth = Math.min(Math.max(this._startWidth + delta, MIN_WIDTH), maxWidth)
    this.element.style.width = `${newWidth}px`
  }

  _stopResize() {
    document.removeEventListener("mousemove", this._boundMove)
    document.removeEventListener("mouseup",   this._boundUp)
    document.body.style.userSelect = ""
    document.body.style.cursor     = ""
    localStorage.setItem(STORAGE_KEY, this.element.offsetWidth)
  }

  _restoreWidth() {
    const saved = parseInt(localStorage.getItem(STORAGE_KEY), 10)
    if (saved && saved >= MIN_WIDTH) this.element.style.width = `${saved}px`
  }

  // Injecte la poignée dynamiquement pour ne pas toucher le HTML ERB
  _injectHandle() {
    if (this.element.querySelector(".doc-chat-resize-handle")) return
    const handle = document.createElement("div")
    handle.className = "doc-chat-resize-handle"
    handle.setAttribute("aria-hidden", "true")
    handle.addEventListener("mousedown", this.startResize.bind(this))
    this.element.prepend(handle)
  }
}
