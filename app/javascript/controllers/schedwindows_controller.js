import { Controller } from "@hotwired/stimulus"

// Repeatable reward time-windows. Each window has its own weekday chips + from/to
// hour. "Add" clones a <template> row (with a unique index so Rails groups the
// fields per window); "Remove" drops a row.
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("IDX", `n${Date.now()}`)
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    const row = event.target.closest("[data-schedwindows-target='row']")
    if (row) row.remove()
  }
}
