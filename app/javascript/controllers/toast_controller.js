import { Controller } from "@hotwired/stimulus"

// Top-right toast: slides in, auto-dismisses after 4s, X closes immediately.
export default class extends Controller {
  static targets = ["item"]

  // Entrance is CSS-driven (keyframe), so the toast is visible even if JS is
  // delayed. Here we only schedule auto-dismiss and wire the close button.
  connect() {
    this.itemTargets.forEach((el) => {
      el._toastTimer = setTimeout(() => this.dismiss(el), 4000)
    })
  }

  close(e) { this.dismiss(e.currentTarget.closest(".l-toast")) }

  dismiss(el) {
    if (!el) return
    clearTimeout(el._toastTimer)
    el.classList.add("leaving")
    setTimeout(() => {
      el.remove()
      if (this.element.childElementCount === 0) this.element.remove()
    }, 320)
  }
}
