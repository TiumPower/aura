import { Controller } from "@hotwired/stimulus"

// Birthday field: formats input as DD/MM/YYYY as the user types (digits only),
// and keeps the remaining part of the DD/MM/YYYY template visible behind the
// cursor (a "ghost" overlay) so it's clear what to type next.
export default class extends Controller {
  static targets = ["input", "ghost"]
  static TEMPLATE = "DD/MM/YYYY"

  connect() { this.render() }

  format() {
    const d = this.inputTarget.value.replace(/\D/g, "").slice(0, 8)
    let out = d.slice(0, 2)
    if (d.length > 2) out += "/" + d.slice(2, 4)
    if (d.length > 4) out += "/" + d.slice(4, 8)
    this.inputTarget.value = out
    this.render()
  }

  render() {
    if (!this.hasGhostTarget) return
    const v = this.inputTarget.value
    const remaining = this.constructor.TEMPLATE.slice(v.length)
    this.ghostTarget.textContent = ""
    // Typed portion is transparent (the real input renders it on top); the
    // remaining template shows muted.
    const typed = document.createElement("span")
    typed.style.color = "transparent"
    typed.textContent = v
    const rest = document.createElement("span")
    rest.style.color = "var(--ink-2)"
    rest.textContent = remaining
    this.ghostTarget.append(typed, rest)
  }
}
