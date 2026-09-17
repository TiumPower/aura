import { Controller } from "@hotwired/stimulus"

// Hide the "Add to Home Screen" guidance when the page is already running as an
// installed PWA (opened from the home-screen icon), so it only shows in a normal
// browser tab. Standalone launch is reported by the display-mode media query
// (Android/desktop) and by navigator.standalone (iOS Safari).
export default class extends Controller {
  connect() {
    const standalone =
      (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches) ||
      window.navigator.standalone === true
    if (standalone) this.element.hidden = true
  }
}
