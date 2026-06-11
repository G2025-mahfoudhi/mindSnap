function setDimensions() {
  document.documentElement.style.setProperty("--vh", window.innerHeight + "px")

  const footer = document.querySelector(".footer")
  if (footer) {
    document.documentElement.style.setProperty("--footer-height", footer.offsetHeight + "px")
  }
}

setDimensions()
window.addEventListener("resize", setDimensions)
document.addEventListener("turbo:load", setDimensions)
document.addEventListener("turbo:render", setDimensions)
