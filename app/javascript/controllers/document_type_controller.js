import { Controller } from "@hotwired/stimulus"

const FILE_TYPES = ["Fichier"]

export default class extends Controller {
  static targets = ["select", "fileField", "urlField", "contentField"]

  connect() {
    this.update()
  }

  update() {
    const type = this.selectTarget.value
    this.fileFieldTarget.hidden = !FILE_TYPES.includes(type)
    this.urlFieldTarget.hidden = type !== "Lien"
    this.contentFieldTarget.hidden = type !== "Note"
    if (type !== "Note") {
      this.dispatch("hide", { bubbles: true })
    }
  }
}
