import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "cropImage"]

  connect() {
    this.cropper = null
    this.cropModal = null
    this.pendingFile = null
  }

  disconnect() {
    this.destroyCropper()
  }

  triggerInput() {
    this.inputTarget.click()
  }

  openCropperFromCurrent() {
    const currentUrl = this.inputTarget.dataset.currentAvatar
    if (!currentUrl) return
    this.openCropper(currentUrl)
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.pendingFile = file
    const reader = new FileReader()
    reader.onload = (e) => {
      if (this.hasPreviewTarget) {
        this.previewTarget.src = e.target.result
        this.previewTarget.classList.remove("d-none")
        this.previewTarget.style.cursor = "zoom-in"
      }
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.classList.add("d-none")
      }
      this.openCropper(e.target.result)
    }
    reader.readAsDataURL(file)
  }

  openCropper(imageUrl) {
    const modalEl = document.getElementById("avatarCropModal")
    if (!modalEl || !this.hasCropImageTarget) return

    this.originalSrc = this.hasPreviewTarget ? this.previewTarget.src : null
    this.cropImageTarget.src = imageUrl

    if (!this.cropModal) {
      this.cropModal = new bootstrap.Modal(modalEl, { backdrop: "static", keyboard: false })

      modalEl.addEventListener("shown.bs.modal", () => {
        this.initCropper()
      })

      modalEl.addEventListener("hidden.bs.modal", () => {
        this.destroyCropper()
      })
    }

    this.cropModal.show()
  }

  initCropper() {
    this.destroyCropper()
    if (!this.hasCropImageTarget) return

    this.cropper = new Cropper(this.cropImageTarget, {
      aspectRatio: 1,
      viewMode: 1,
      autoCropArea: 1,
      responsive: true,
      guides: true,
      center: true,
      highlight: false,
      background: false,
      movable: true,
      zoomable: true,
      rotatable: false,
      scalable: false
    })
  }

  applyCrop() {
    if (!this.cropper || !this.hasInputTarget) return

    const canvas = this.cropper.getCroppedCanvas({ width: 400, height: 400 })
    canvas.toBlob((blob) => {
      const file = new File([blob], this.pendingFile?.name || "avatar.jpg", {
        type: "image/jpeg",
        lastModified: Date.now()
      })
      const dt = new DataTransfer()
      dt.items.add(file)
      this.inputTarget.files = dt.files

      if (this.hasPreviewTarget) {
        this.previewTarget.src = URL.createObjectURL(blob)
        this.previewTarget.classList.remove("d-none")
      }
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.classList.add("d-none")
      }

      this.closeCropper()
    }, "image/jpeg", 0.9)
  }

  cancelCrop() {
    this.closeCropper()
    if (this.pendingFile) {
      this.inputTarget.value = ""
      this.pendingFile = null
    }
    if (this.hasPreviewTarget && this.originalSrc) {
      this.previewTarget.src = this.originalSrc
    }
  }

  closeCropper() {
    this.destroyCropper()
    if (this.cropModal) {
      this.cropModal.hide()
    }
  }

  destroyCropper() {
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  }
}
