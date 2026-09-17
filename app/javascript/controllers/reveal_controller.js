import { Controller } from "@hotwired/stimulus"

// Toggle a password field between hidden and visible.
export default class extends Controller {
  static targets = ["input", "on", "off"]

  toggle() {
    const reveal = this.inputTarget.type === "password"
    this.inputTarget.type = reveal ? "text" : "password"
    if (this.hasOnTarget) this.onTarget.hidden = !reveal
    if (this.hasOffTarget) this.offTarget.hidden = reveal
  }
}
