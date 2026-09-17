import { Controller } from "@hotwired/stimulus"

// Interactive 1–5 star picker backing a hidden input.
export default class extends Controller {
  static targets = ["star", "input"]

  connect() { this.paint(parseInt(this.inputTarget.value, 10) || 0) }

  set(e) {
    const v = parseInt(e.currentTarget.dataset.value, 10)
    this.inputTarget.value = v
    this.paint(v)
  }

  paint(v) {
    this.starTargets.forEach((s, i) => {
      s.textContent = i < v ? "★" : "☆"
      s.style.opacity = i < v ? "1" : ".45"
    })
  }
}
