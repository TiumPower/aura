import { Controller } from "@hotwired/stimulus"

// Enlarge a check-in QR into a centered fullscreen overlay so staff can display
// it big enough to scan (or read the detail). Close via the ✕, the backdrop, or
// the Escape key.
export default class extends Controller {
  static targets = ["overlay"]

  open() {
    this.overlayTarget.classList.add("is-open")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.overlayTarget.classList.remove("is-open")
    document.body.style.overflow = ""
  }

  // Close only when the backdrop itself (not the card) is clicked.
  backdrop(e) { if (e.target === this.overlayTarget) this.close() }

  connect() {
    this._esc = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._esc)
  }

  disconnect() {
    document.removeEventListener("keydown", this._esc)
    document.body.style.overflow = ""
  }
}
