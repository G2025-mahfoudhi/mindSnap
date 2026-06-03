import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resize()
  }

  resize() {
    const el = this.element
    const style = getComputedStyle(el)

    // scrollHeight = contenu + padding, SANS les bordures.
    // Avec box-sizing: border-box, il faut les ajouter manuellement
    // pour que la textarea ait la même hauteur que le bouton Bootstrap (38px).
    const borders = parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth)
    const maxHeight = parseFloat(style.maxHeight) || Infinity

    el.style.height = "auto"
    const totalHeight = Math.min(el.scrollHeight + borders, maxHeight)
    el.style.height = `${totalHeight}px`
    el.style.overflowY = el.scrollHeight + borders > maxHeight ? "auto" : "hidden"
  }
}
