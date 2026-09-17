import { Controller } from "@hotwired/stimulus"

// Generic add/remove for a list of form rows backed by a <template>.
// New rows get a unique index (gaps are fine — the server reads params.values).
export default class extends Controller {
  static targets = ["list", "template"]
  static values = { next: Number, min: Number }

  add() {
    const i = this.nextValue
    this.nextValue = i + 1
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replace(/__INDEX__/g, i))
  }

  remove(e) {
    const min = this.hasMinValue ? this.minValue : 1
    if (this.listTarget.querySelectorAll("[data-row]").length <= min) return
    e.target.closest("[data-row]").remove()
  }
}
