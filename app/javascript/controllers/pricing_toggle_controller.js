import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "proAmount", "proSub", "businessAmount", "businessSub", "savings"]

  connect() {
    this.showMonthly()
  }

  switch() {
    if (this.toggleTarget.checked) {
      this.showAnnual()
    } else {
      this.showMonthly()
    }
  }

  showMonthly() {
    this.proAmountTarget.textContent = "5,90 €"
    this.proSubTarget.textContent = "/ mois"
    this.businessAmountTarget.textContent = "15 €"
    this.businessSubTarget.textContent = "/ mois"
    this.savingsTargets.forEach(el => el.classList.add("d-none"))
  }

  showAnnual() {
    this.proAmountTarget.textContent = "4,90 €"
    this.proSubTarget.textContent = "/ mois · facturé 58,80 €/an"
    this.businessAmountTarget.textContent = "12,50 €"
    this.businessSubTarget.textContent = "/ mois · facturé 150 €/an"
    this.savingsTargets.forEach(el => el.classList.remove("d-none"))
  }
}
