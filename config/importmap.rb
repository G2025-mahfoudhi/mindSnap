# Pin npm packages by running ./bin/importmap

pin "application"
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
pin "@popperjs/core", to: "popper.js", preload: true
