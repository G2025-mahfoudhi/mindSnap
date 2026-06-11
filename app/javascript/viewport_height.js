function setDimensions() {
  document.documentElement.style.setProperty("--vh", window.innerHeight + "px")

  const footer = document.querySelector(".footer")
  if (footer) {
    const h = footer.offsetHeight
    if (h > 0) {
      document.documentElement.style.setProperty("--footer-height", h + "px")
    }
  }
}

setDimensions()
window.addEventListener("resize", setDimensions)
document.addEventListener("turbo:load", setDimensions)
document.addEventListener("turbo:render", setDimensions)

// Detecte les changements de hauteur du footer (wrapping sur fenêtre réduite)
const _footer = document.querySelector(".footer")
if (_footer && window.ResizeObserver) {
  new ResizeObserver(setDimensions).observe(_footer)
}
