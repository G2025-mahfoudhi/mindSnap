import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tagCheckbox", "selectAllLabel", "selectionCount", "renameInput"]
  static values = { active: String }

  connect() {
    this.initTooltips()
    document.addEventListener("turbo:render", () => this.initTooltips())
  }

  updateSelectionCount() {
    const checked = this.tagCheckboxTargets.filter((cb) => cb.checked)
    const count = checked.length
    if (this.hasSelectionCountTarget) {
      this.selectionCountTarget.textContent = `${count} tag(s) sélectionné(s)`
    }
    if (this.hasSelectAllLabelTarget) {
      const allChecked = checked.length === this.tagCheckboxTargets.length
        && this.tagCheckboxTargets.length > 0
      this.selectAllLabelTarget.textContent = allChecked ? "Tout désélectionner" : "Tout sélectionner"
    }
  }

  toggleTagSelection() {
    const allChecked = this.tagCheckboxTargets.every((cb) => cb.checked)
    this.tagCheckboxTargets.forEach((cb) => { cb.checked = !allChecked })
    this.updateSelectionCount()
  }

  filterTags(event) {
    const rawQuery = event.currentTarget.value.toLowerCase().trim()
    const query = rawQuery.normalize("NFD").replace(/[\u0300-\u036f]/g, "")

    const list = this.element.querySelector("#tags_list")
    if (!list) return

    const rows = Array.from(list.querySelectorAll(".tag-row"))
    const scored = rows.map((row) => {
      const rawName = (row.dataset.tagName || "").toLowerCase()
      const name = rawName.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      const idx = name.indexOf(query)
      let score = -1
      if (query.length > 0 && idx !== -1) {
        score = Math.round(((query.length / name.length) * 50) + ((name.length - idx) / name.length * 50))
      }
      return { row, score, name }
    })

    if (query.length === 0) {
      scored.sort((a, b) => a.name.localeCompare(b.name))
      scored.forEach(({ row }) => {
        row.classList.remove("hidden-by-filter")
      })
    } else {
      scored.sort((a, b) => b.score - a.score)
      scored.forEach(({ row, score }) => {
        row.classList.toggle("hidden-by-filter", score < 0)
      })
    }
    scored.forEach(({ row }) => list.appendChild(row))
  }

  startRename(event) {
    const tagId = event.currentTarget.dataset.tagId
    const display = this.element.querySelector(`.tag-name-display[data-tag-id="${tagId}"]`)
    const renameForm = this.element.querySelector(`.tag-rename-form[data-tag-id="${tagId}"]`)
    const errorEl = this.element.querySelector(`.tag-rename-error[data-tag-id="${tagId}"]`)
    if (display) display.classList.add("d-none")
    if (errorEl) errorEl.classList.add("d-none")
    if (renameForm) {
      renameForm.classList.remove("d-none")
      renameForm.querySelector("input[type=text]")?.focus()
    }
  }

  cancelRename(event) {
    const tagId = event.currentTarget.dataset.tagId
    const display = this.element.querySelector(`.tag-name-display[data-tag-id="${tagId}"]`)
    const renameForm = this.element.querySelector(`.tag-rename-form[data-tag-id="${tagId}"]`)
    const errorEl = this.element.querySelector(`.tag-rename-error[data-tag-id="${tagId}"]`)
    if (display) display.classList.remove("d-none")
    if (renameForm) renameForm.classList.add("d-none")
    if (errorEl) errorEl.classList.add("d-none")
  }

  async submitRename(event) {
    const tagId = event.currentTarget.dataset.tagId
    const input = this.element.querySelector(`input[data-tag-id="${tagId}"]`)
    const errorEl = this.element.querySelector(`.tag-rename-error[data-tag-id="${tagId}"]`)
    if (!input) return

    const newName = input.value.trim()
    if (!newName) {
      if (errorEl) {
        errorEl.textContent = "Le nom ne peut pas être vide."
        errorEl.classList.remove("d-none")
      }
      return
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    try {
      const response = await fetch(`/tags/${tagId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ tag: { name: newName } })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else if (response.status === 422) {
        const data = await response.json()
        if (errorEl) {
          errorEl.textContent = data.errors?.join(", ") || "Erreur de validation."
          errorEl.classList.remove("d-none")
        }
      }
    } catch (err) {
      console.error("Rename failed:", err)
      if (errorEl) {
        errorEl.textContent = "Erreur réseau. Réessaie."
        errorEl.classList.remove("d-none")
      }
    }
  }

  initTooltips() {
    if (typeof bootstrap !== "undefined") {
      this.element.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
        new bootstrap.Tooltip(el)
      })
    }
  }
}
