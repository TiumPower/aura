# Pin npm packages by running ./bin/importmap

pin "application"
pin "confirm_dialog"
pin "toast"
pin "leaflet_loader" # loads the vendored Leaflet build on demand (map pages only)
pin "map_kit"        # shared map setup: tiles, HTML pins, price labels
pin "jsqr" # vendored fallback QR decoder (browsers without BarcodeDetector)
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
