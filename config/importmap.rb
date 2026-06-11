# Pin npm packages by running ./bin/importmap

pin "application"
pin "confirm", to: "confirm.js"
pin "@hotwired/turbo-rails", to: "turbo.js"
pin "@rails/actioncable/src", to: "actioncable.esm.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Bootstrap 5 ESM bundle (contient Popper.js) charge depuis jsDelivr.
# La version gem bootstrap-5.3.8 distribue bootstrap.min.js en UMD, pas
# compatible avec un import ESM via importmap, ce qui faisait que les
# data-bs-* (offcanvas, dropdown, etc.) ne s'initialisaient pas.
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js", preload: true
pin "sweetalert2", to: "https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.esm.all.min.js"
pin "@popperjs/core", to: "popper.js", preload: true
pin "cropperjs", to: "https://cdn.jsdelivr.net/npm/cropperjs@1.6.2/dist/cropper.esm.min.js"
pin "local_time", to: "local_time.js"
