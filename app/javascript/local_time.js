function convertLocalTimes() {
  document.querySelectorAll("time[data-localtime]").forEach(el => {
    const date = new Date(el.getAttribute("datetime"))
    if (isNaN(date)) return

    const format = el.dataset.localtime
    const timeOpts = { hour: "2-digit", minute: "2-digit" }
    const dateOpts = { day: "2-digit", month: "2-digit", year: "numeric" }

    if (format === "time") {
      el.textContent = date.toLocaleTimeString("fr-FR", timeOpts)
    } else if (format === "date") {
      el.textContent = date.toLocaleDateString("fr-FR", dateOpts)
    } else if (format === "datetime") {
      el.textContent = date.toLocaleDateString("fr-FR", dateOpts) +
                       " à " +
                       date.toLocaleTimeString("fr-FR", timeOpts)
    }
  })
}

document.addEventListener("turbo:load", convertLocalTimes)
document.addEventListener("turbo:render", convertLocalTimes)
