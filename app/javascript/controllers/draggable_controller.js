import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dragging = false
    this.startX = 0
    this.startY = 0
    this.startLeft = 0
    this.startTop = 0

    this.element.style.cursor = "grab"
    this.element.style.userSelect = "none"

    this.onMouseDown  = this.onMouseDown.bind(this)
    this.onMouseMove  = this.onMouseMove.bind(this)
    this.onMouseUp    = this.onMouseUp.bind(this)
    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchMove  = this.onTouchMove.bind(this)
    this.onTouchEnd   = this.onTouchEnd.bind(this)
    this.onResize     = this.onResize.bind(this)

    this.element.addEventListener("mousedown",  this.onMouseDown)
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    window.addEventListener("resize", this.onResize)
    window.addEventListener("orientationchange", this.onResize)

  }

  disconnect() {
    this.element.removeEventListener("mousedown",  this.onMouseDown)
    this.element.removeEventListener("touchstart", this.onTouchStart)
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup",   this.onMouseUp)
    document.removeEventListener("touchmove", this.onTouchMove)
    document.removeEventListener("touchend",  this.onTouchEnd)
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("orientationchange", this.onResize)
  }

  onResize() {
    // Defer so the browser has applied new viewport dimensions (critical on iOS orientation change)
    requestAnimationFrame(() => this._applyResize())
  }

  _applyResize() {
    // En mode CSS (position non customisée), Bootstrap gère via right/bottom — rien à faire.
    // En mode drag (left/top inline), on recadre dans les nouvelles limites de l'écran.
    if (!this.isDragged()) return

    const left = parseFloat(this.element.style.left)
    const top  = parseFloat(this.element.style.top)
    const maxX = window.innerWidth  - this.element.offsetWidth
    const maxY = window.innerHeight - this.element.offsetHeight - this.footerHeight

    // Si la position sauvegardée sort de l'écran réduit, on revient à la position par défaut.
    if (left > maxX || top > maxY || left < 0 || top < 0) {
      this.resetToDefault()
    } else {
      const clampedLeft = Math.min(Math.max(0, left), maxX)
      const clampedTop  = Math.min(Math.max(0, top),  maxY)
      this.element.style.left = `${clampedLeft}px`
      this.element.style.top  = `${clampedTop}px`
    }
  }

  // Vérifie si l'élément est en mode positionnement par drag (left/top) ou CSS (right/bottom).
  isDragged() {
    const left = this.element.style.left
    return left && left !== "" && left !== "auto"
  }

  resetToDefault() {
    this.element.style.left   = ""
    this.element.style.top    = ""
    this.element.style.right  = "1.5rem"
    this.element.style.bottom = "6rem"
  }

  onMouseDown(e) {
    if (e.button !== 0) return
    this.startDrag(e.clientX, e.clientY)
    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup",   this.onMouseUp)
  }

  onMouseMove(e) {
    this.doDrag(e.clientX, e.clientY)
  }

  onMouseUp(e) {
    this.endDrag(e.target)
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup",   this.onMouseUp)
  }

  onTouchStart(e) {
    const t = e.touches[0]
    this.startDrag(t.clientX, t.clientY)
    document.addEventListener("touchmove", this.onTouchMove, { passive: false })
    document.addEventListener("touchend",  this.onTouchEnd)
  }

  onTouchMove(e) {
    e.preventDefault()
    const t = e.touches[0]
    this.doDrag(t.clientX, t.clientY)
  }

  onTouchEnd() {
    this.endDrag()
    document.removeEventListener("touchmove", this.onTouchMove)
    document.removeEventListener("touchend",  this.onTouchEnd)
  }

  startDrag(clientX, clientY) {
    this.dragging = true
    this.moved = false
    this.element.style.cursor = "grabbing"

    const rect = this.element.getBoundingClientRect()
    this.startX    = clientX
    this.startY    = clientY
    this.startLeft = rect.left
    this.startTop  = rect.top

    this.element.style.right  = "auto"
    this.element.style.bottom = "auto"
    this.element.style.left   = `${rect.left}px`
    this.element.style.top    = `${rect.top}px`
  }

  doDrag(clientX, clientY) {
    if (!this.dragging) return

    const dx = clientX - this.startX
    const dy = clientY - this.startY

    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) this.moved = true

    const maxX = window.innerWidth  - this.element.offsetWidth
    const maxY = window.innerHeight - this.element.offsetHeight - this.footerHeight

    const newLeft = Math.min(Math.max(0, this.startLeft + dx), maxX)
    const newTop  = Math.min(Math.max(0, this.startTop  + dy), maxY)

    this.element.style.left = `${newLeft}px`
    this.element.style.top  = `${newTop}px`
  }

  endDrag(target) {
    if (!this.dragging) return
    this.dragging = false
    this.element.style.cursor = "grab"

    if (this.moved) {
      const stop = (e) => { e.preventDefault(); e.stopPropagation() }
      this.element.addEventListener("click", stop, { once: true, capture: true })
    }
  }

  get footerHeight() {
    const footer = document.querySelector(".footer")
    return footer ? footer.offsetHeight : 0
  }
}
