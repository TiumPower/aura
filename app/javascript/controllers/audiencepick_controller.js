import { Controller } from "@hotwired/stimulus"

// Multi-select group picker for "send campaign notification". Toggles a checkbox
// panel and keeps the send button's count label + enabled state in sync so the
// merchant can send one campaign to several customer groups at once.
export default class extends Controller {
  static targets = ["panel", "check", "send", "count", "button"]

  connect() {
    this._outside = (e) => { if (!this.element.contains(e.target)) this.close() }
    document.addEventListener("click", this._outside)
    this.update()
  }

  disconnect() { document.removeEventListener("click", this._outside) }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.panelTarget.hidden = !this.panelTarget.hidden
  }

  close() { if (this.hasPanelTarget) this.panelTarget.hidden = true }

  update() {
    const n = this.checkTargets.filter((c) => c.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = n
    if (this.hasSendTarget) this.sendTarget.disabled = n === 0
  }
}
