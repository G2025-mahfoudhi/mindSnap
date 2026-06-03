import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { storageKey: { type: String, default: "draggable-position" } }

  connect() {
    this.dragging = false
    this.startX = 0
    this.startY = 0
    this.startLeft = 0
    this.startTop = 0

    this.element.style.cursor = "grab"
    this.element.style.userSelect = "none"

    this.onMouseDown = this.onMouseDown.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp   = this.onMouseUp.bind(this)
    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchMove  = this.onTouchMove.bind(this)
    this.onTouchEnd   = this.onTouchEnd.bind(this)

    this.element.addEventListener("mousedown",  this.onMouseDown)
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })

    this.restorePosition()
  }

  disconnect() {
    this.element.removeEventListener("mousedown",  this.onMouseDown)
    this.element.removeEventListener("touchstart", this.onTouchStart)
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup",   this.onMouseUp)
    document.removeEventListener("touchmove", this.onTouchMove)
    document.removeEventListener("touchend",  this.onTouchEnd)
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

    // Switch to top/left absolute positioning
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

    this.savePosition(
      parseFloat(this.element.style.left),
      parseFloat(this.element.style.top)
    )

    // Prevent the click event if the element was dragged
    if (this.moved) {
      const stop = (e) => { e.preventDefault(); e.stopPropagation() }
      this.element.addEventListener("click", stop, { once: true, capture: true })
    }
  }

  savePosition(left, top) {
    localStorage.setItem(this.storageKeyValue, JSON.stringify({ left, top }))
  }

  get footerHeight() {
    const footer = document.querySelector(".footer")
    return footer ? footer.offsetHeight : 0
  }

  restorePosition() {
    const saved = localStorage.getItem(this.storageKeyValue)
    if (!saved) return

    const { left, top } = JSON.parse(saved)
    const maxX   = window.innerWidth  - this.element.offsetWidth
    const maxY   = window.innerHeight - this.element.offsetHeight - this.footerHeight

    this.element.style.right  = "auto"
    this.element.style.bottom = "auto"
    this.element.style.left   = `${Math.min(Math.max(0, left), maxX)}px`
    this.element.style.top    = `${Math.min(Math.max(0, top),  maxY)}px`
  }
}
