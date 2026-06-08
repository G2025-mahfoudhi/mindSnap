import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = { url: String }

  connect() {
    this._onShow = this.load.bind(this)
    this.element.addEventListener("show.bs.offcanvas", this._onShow)
  }

  disconnect() {
    this.element.removeEventListener("show.bs.offcanvas", this._onShow)
  }

  load() {
    if (!this.frameTarget.getAttribute("src")) {
      this.frameTarget.setAttribute("src", this.urlValue)
    }
  }
}
