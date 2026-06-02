// ============================================================
// Contrôleur Stimulus : faq-search
// Gère la FAQ : recherche en temps réel + scroll spy sidebar.
//
// Comportements :
//   a) Recherche : filtre les questions selon la saisie
//   b) ScrollSpy  : surligne la catégorie active dans le sidebar
//                   au scroll (IntersectionObserver) et au clic
//
// Cibles data-faq-search-target :
//   - input       : le champ de recherche
//   - item        : chaque item FAQ (div.faq-item)
//   - category    : chaque section de catégorie (<section>)
//   - sidebarLink : chaque lien du sidebar
//   - empty       : le message "aucun résultat"
//   - content     : le conteneur principal
// ============================================================

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "category", "sidebarLink", "empty", "content"]

  // ==========================================================
  // Lifecycle : au chargement, on active le ScrollSpy
  // ==========================================================
  connect() {
    this.#initScrollSpy()
  }

  // Nettoie l'observer quand le contrôleur est déconnecté
  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  // ==========================================================
  // Recherche : filtrage en temps réel
  // ==========================================================
  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()

    if (query === "") {
      this.#resetAll()
      return
    }

    let anyVisible = false

    this.categoryTargets.forEach((category) => {
      const items = category.querySelectorAll("[data-faq-search-target='item']")
      let categoryHasVisible = false

      items.forEach((item) => {
        const words = item.dataset.faqSearchWordsValue || ""
        const isMatch = words.includes(query)
        item.classList.toggle("d-none", !isMatch)
        if (isMatch) categoryHasVisible = true
      })

      category.classList.toggle("d-none", !categoryHasVisible)
      if (categoryHasVisible) anyVisible = true
    })

    this.emptyTarget.classList.toggle("d-none", anyVisible)
    this.#updateSidebar(query)
  }

  // ==========================================================
  // ScrollSpy : surligne la catégorie active dans le sidebar
  // ==========================================================

  // Initialise l'IntersectionObserver sur chaque section catégorie.
  // rootMargin : la section est considérée "active" quand elle
  // occupe la partie haute du viewport (-20% en haut, -60% en bas).
  #initScrollSpy() {
    this.observer = new IntersectionObserver(
      (entries) => this.#onIntersect(entries),
      {
        rootMargin: "-15% 0px -70% 0px", // déclenche quand la section est dans le tiers supérieur
        threshold: 0
      }
    )

    this.categoryTargets.forEach((category) => {
      this.observer.observe(category)
    })
  }

  // Appelé quand une section entre/sort du viewport.
  // Cherche le lien sidebar correspondant (href="#category-xxx")
  // et applique/retire la classe .active.
  #onIntersect(entries) {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return

      // Retirer .active de tous les liens
      this.sidebarLinkTargets.forEach((link) => {
        link.classList.remove("active")
      })

      // Ajouter .active sur le lien correspondant à la section visible
      const sectionId = entry.target.id
      const activeLink = this.sidebarLinkTargets.find(
        (link) => link.getAttribute("href") === `#${sectionId}`
      )
      if (activeLink) {
        activeLink.classList.add("active")
      }
    })
  }

  // Scroll smooth vers la section quand on clique sur un lien sidebar.
  // Gère le décalage de la navbar sticky (80px).
  scrollTo(event) {
    event.preventDefault()
    const targetId = event.currentTarget.getAttribute("href")
    const target = document.querySelector(targetId)

    if (target) {
      // Calculer la position en tenant compte de la navbar sticky
      const navbarHeight = 72 // hauteur approximative navbar + marge
      const top = target.getBoundingClientRect().top + window.scrollY - navbarHeight

      window.scrollTo({ top, behavior: "smooth" })
    }
  }

  // ==========================================================
  // Helpers privés
  // ==========================================================

  #resetAll() {
    this.itemTargets.forEach((item) => item.classList.remove("d-none"))
    this.categoryTargets.forEach((cat) => cat.classList.remove("d-none"))
    this.emptyTarget.classList.add("d-none")
    this.#updateSidebar("")
  }

  #updateSidebar(query) {
    this.sidebarLinkTargets.forEach((link) => {
      if (query === "") {
        link.classList.remove("opacity-25")
        return
      }
      const targetId = link.getAttribute("href")?.replace("#", "")
      const category = document.getElementById(targetId)
      if (category && category.classList.contains("d-none")) {
        link.classList.add("opacity-25")
      } else {
        link.classList.remove("opacity-25")
      }
    })
  }
}
