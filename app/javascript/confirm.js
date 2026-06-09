import Swal from "sweetalert2"
import { Turbo } from "@hotwired/turbo-rails"

// Remplace le confirm() natif de Turbo par SweetAlert2 pour tous les
// data-turbo-confirm dans l'application.
Turbo.config.forms.confirm = (message) => {
  return Swal.fire(buildOptions(message)).then(r => r.isConfirmed)
}

function buildOptions(message) {
  const danger = /supprimer|effacer|réinitialiser|irréversible|définitivement/i.test(message)
  return {
    title: message,
    icon: danger ? "warning" : "question",
    showCancelButton: true,
    confirmButtonText: danger ? "Supprimer" : "Confirmer",
    cancelButtonText: "Annuler",
    confirmButtonColor: danger ? "#dc3545" : "#3d7f7e",
    cancelButtonColor: "#6c757d",
    reverseButtons: true,
    focusCancel: true,
    customClass: { popup: "swal-mindsnap" }
  }
}

export { Swal, buildOptions }
