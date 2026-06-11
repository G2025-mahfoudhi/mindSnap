function setVh() {
  document.documentElement.style.setProperty("--vh", window.innerHeight + "px")
}

setVh()
window.addEventListener("resize", setVh)
document.addEventListener("turbo:load", setVh)
document.addEventListener("turbo:render", setVh)
