import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash messages.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => {
      this.element.style.transition = "opacity .3s, transform .3s"
      this.element.style.opacity = "0"
      this.element.style.transform = "translate(-50%, -8px)"
      setTimeout(() => this.element.remove(), 320)
    }, 3200)
  }
  disconnect() { clearTimeout(this.timeout) }
}
