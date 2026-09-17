import { Controller } from "@hotwired/stimulus"

// Emoji picker that stays hidden until the icon field is focused/clicked, then
// reveals a popover grid. Picking an emoji fills the field and closes the popover;
// clicking outside also closes it.
export default class extends Controller {
  static targets = ["input", "panel"]

  connect() {
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.hide() }
    document.addEventListener("click", this.onDocClick)
  }

  disconnect() { document.removeEventListener("click", this.onDocClick) }

  show() { if (this.hasPanelTarget) this.panelTarget.hidden = false }
  hide() { if (this.hasPanelTarget) this.panelTarget.hidden = true }

  pick(event) {
    event.preventDefault()
    if (!this.hasInputTarget) return
    this.inputTarget.value = event.currentTarget.dataset.emoji
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.hide()
  }
}
