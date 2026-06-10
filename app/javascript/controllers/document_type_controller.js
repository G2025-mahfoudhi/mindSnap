import { Controller } from "@hotwired/stimulus"

const FILE_TYPES = ["Fichier"]

export default class extends Controller {
  static targets = ["select", "fileField", "urlField", "contentField"]

  connect() {
    this.update()
  }

  update() {
    const type = this.selectTarget.value
    this.fileFieldTargets.forEach(el => { el.hidden = !FILE_TYPES.includes(type) })
    this.urlFieldTargets.forEach(el => { el.hidden = type !== "Lien" })
    this.contentFieldTargets.forEach(el => { el.hidden = type !== "Note" })
    if (type !== "Note") {
      this.dispatch("hide", { bubbles: true })
    }
  }
}
