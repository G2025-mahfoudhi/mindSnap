import Swal from "sweetalert2"
import { Turbo } from "@hotwired/turbo-rails"

const confirmHandler = (message) => {
  return Swal.fire(buildOptions(message)).then(r => r.isConfirmed)
}

Turbo.config.forms.confirm = confirmHandler
Turbo.config.drive.confirm = confirmHandler

function buildOptions(message) {
  const danger = /supprimer|effacer|réinitialiser|irréversible|définitivement/i.test(message)
  const isLong = message.length > 80

  return {
    title: isLong ? (danger ? "Confirmer la suppression" : "Confirmation") : message,
    text: isLong ? message : undefined,
    icon: danger ? "warning" : "question",
    showCancelButton: true,
    confirmButtonText: danger ? "Supprimer" : "Confirmer",
    cancelButtonText: "Annuler",
    confirmButtonColor: danger ? "#dc3545" : "#3d7f7e",
    cancelButtonColor: "#6c757d",
    reverseButtons: true,
    focusCancel: danger,
    customClass: { popup: "swal-mindsnap" }
  }
}

export { Swal, buildOptions }
