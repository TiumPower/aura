import { Controller } from "@hotwired/stimulus"

// Copy a value to the clipboard and briefly confirm on the button.
export default class extends Controller {
  static values = { text: String }
  static targets = ["label"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch (e) {
      const ta = document.createElement("textarea")
      ta.value = this.textValue; document.body.appendChild(ta); ta.select()
      try { document.execCommand("copy") } catch (_) {}
      ta.remove()
    }
    if (this.hasLabelTarget) {
      const el = this.labelTarget, prev = el.textContent
      el.textContent = "✓ Đã copy"
      setTimeout(() => { el.textContent = prev }, 1500)
    }
  }
}
