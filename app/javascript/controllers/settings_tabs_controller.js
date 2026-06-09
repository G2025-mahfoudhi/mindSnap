import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "pill", "tagCheckbox", "selectAllLabel", "selectionCount"]
  static values = { active: String }

  connect() {
    this.initTooltips()
  }

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    if (!tab) return

    const currentPanel = this.element.querySelector(".settings-panel.active")
    const nextPanel = this.element.querySelector(`.settings-panel[data-tab="${tab}"]`)
    if (!nextPanel || currentPanel === nextPanel) return

    this.updatePills(tab)
    this.transition(currentPanel, nextPanel)
    window.history.replaceState({}, "", `${window.location.pathname}?tab=${tab}`)
  }

  updatePills(activeTab) {
    this.pillTargets.forEach((pill) => {
      pill.classList.toggle("active", pill.dataset.tab === activeTab)
    })
  }

  transition(from, to) {
    if (!from) {
      to.classList.add("active")
      return
    }

    from.classList.add("settings-panel--exiting")
    from.addEventListener("transitionend", () => {
      from.classList.remove("active", "settings-panel--exiting")
      to.classList.add("active")
    }, { once: true })
  }

  initTooltips() {
    if (typeof bootstrap !== "undefined") {
      this.element.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
        new bootstrap.Tooltip(el)
      })
    }
  }

  updateSelectionCount() {
    const checked = this.tagCheckboxTargets.filter((cb) => cb.checked)
    const count = checked.length
    if (this.hasSelectionCountTarget) {
      this.selectionCountTarget.textContent = `${count} tag(s) sélectionné(s)`
    }
    if (this.hasSelectAllLabelTarget) {
      const allChecked = checked.length === this.tagCheckboxTargets.length
      this.selectAllLabelTarget.textContent = allChecked ? "Tout désélectionner" : "Tout sélectionner"
    }
  }

  toggleTagSelection() {
    const allChecked = this.tagCheckboxTargets.every((cb) => cb.checked)
    this.tagCheckboxTargets.forEach((cb) => { cb.checked = !allChecked })
    this.updateSelectionCount()
  }

  exportByTags(event) {
    const format = event.currentTarget.dataset.settingsTabsFormatParam
    const checked = this.tagCheckboxTargets.filter((cb) => cb.checked)
    if (checked.length === 0) {
      alert("Sélectionne au moins un tag à exporter.")
      return
    }
    const tagIds = checked.map((cb) => cb.value)
    const params = new URLSearchParams()
    tagIds.forEach((id) => params.append("tag_ids[]", id))
    params.append("export_format", format)

    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/settings/export_by_tags"
    form.style.display = "none"
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }
    params.forEach((value, key) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = key
      input.value = value
      form.appendChild(input)
    })
    document.body.appendChild(form)
    form.submit()
    form.remove()
  }

  startRename(event) {
    const tagId = event.currentTarget.dataset.tagId
    const display = this.element.querySelector(`.tag-name-display[data-tag-id="${tagId}"]`)
    const form = this.element.querySelector(`.tag-rename-form[data-tag-id="${tagId}"]`)
    if (display) display.classList.add("d-none")
    if (form) {
      form.classList.remove("d-none")
      form.querySelector("input[type=text]")?.focus()
    }
  }

  cancelRename(event) {
    const tagId = event.currentTarget.dataset.tagId
    const display = this.element.querySelector(`.tag-name-display[data-tag-id="${tagId}"]`)
    const form = this.element.querySelector(`.tag-rename-form[data-tag-id="${tagId}"]`)
    if (display) display.classList.remove("d-none")
    if (form) form.classList.add("d-none")
  }
}
