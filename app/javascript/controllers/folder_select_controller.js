import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "newFolderField"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.newFolderFieldTarget.hidden = this.selectTarget.value !== "new"
  }
}