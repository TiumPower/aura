import { Controller } from "@hotwired/stimulus"

// Periodically refresh a short-lived QR (e.g. the staff self-login QR) so a
// stale screenshot can't be reused. Swaps the box's HTML with a fresh QR.
export default class extends Controller {
  static targets = ["box"]
  static values = { url: String }

  connect() { this.timer = setInterval(() => this.refresh(), 90000) }
  disconnect() { clearInterval(this.timer) }

  async refresh() {
    try {
      const res = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      if (res.ok && this.hasBoxTarget) this.boxTarget.innerHTML = await res.text()
    } catch (e) { /* keep the current QR on a transient error */ }
  }
}
