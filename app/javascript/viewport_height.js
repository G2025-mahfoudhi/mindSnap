function setFooterHeight() {
  const footer = document.querySelector(".footer")
  if (footer) {
    const h = footer.offsetHeight
    if (h > 0) {
      document.documentElement.style.setProperty("--footer-height", h + "px")
    }
  }
}

function setDimensions() {
  // On mobile, use visualViewport.height which already excludes the virtual keyboard.
  // This prevents the layout from jumping when the keyboard opens/closes.
  // On desktop, keep using window.innerHeight.
  const isMobile = window.innerWidth < 768
  const height = (isMobile && window.visualViewport)
    ? window.visualViewport.height
    : window.innerHeight
  document.documentElement.style.setProperty("--vh", height + "px")
  setFooterHeight()
}

setDimensions()

// Desktop + orientation changes
window.addEventListener("resize", setDimensions)
document.addEventListener("turbo:load", setDimensions)
document.addEventListener("turbo:render", setDimensions)

// Mobile keyboard appearance — visualViewport fires before window.resize
if (window.visualViewport) {
  window.visualViewport.addEventListener("resize", setDimensions)
}

// Footer height — react to wrapping on narrow screens
const _footer = document.querySelector(".footer")
if (_footer && window.ResizeObserver) {
  new ResizeObserver(setFooterHeight).observe(_footer)
}