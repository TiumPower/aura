import { Controller } from "@hotwired/stimulus"

// Live-updates the tenant-app preview AND the landlord dashboard chrome as the
// merchant edits brand colours — a real-time review before saving (like Loyalty).
export default class extends Controller {
  static targets = ["primary", "secondary", "frame", "swatch"]

  connect() {
    this._original = {
      primary: this.rootVar("--primary"),
      secondary: this.rootVar("--primary-2"),
    }
    this.apply()
  }

  // Restore the saved palette if the user leaves without saving.
  disconnect() {
    if (this._saved) return
    this.setRoot(this._original.primary, this._original.secondary)
  }

  // A preset swatch was clicked → load its colours into the pickers.
  preset(e) {
    const el = e.currentTarget
    if (this.hasPrimaryTarget)   this.primaryTarget.value = el.dataset.primary
    if (this.hasSecondaryTarget) this.secondaryTarget.value = el.dataset.secondary
    this.markActive(el)
    this.apply()
  }

  // A colour picker changed.
  changed() {
    this.markActive(null)
    this.apply()
  }

  markSaved() { this._saved = true }

  apply() {
    const p = this.hasPrimaryTarget ? this.primaryTarget.value : this._original.primary
    const s = this.hasSecondaryTarget ? this.secondaryTarget.value : this._original.secondary
    this.setRoot(p, s)                 // whole dashboard chrome
    if (this.hasFrameTarget) {         // preview phone
      this.frameTarget.style.setProperty("--pv-primary", p)
      this.frameTarget.style.setProperty("--pv-secondary", s)
      // Mirror the server's choice of text colour (Workspace#readable_ink), so
      // dragging to a pale colour previews dark text rather than unreadable white.
      this.frameTarget.style.setProperty("--pv-ink", this.readableInk(p))
    }
  }

  // Whichever of white / near-black contrasts better, by WCAG ratio.
  readableInk(hex) {
    const m = String(hex || "").replace("#", "")
    if (!/^[0-9a-f]{6}$/i.test(m)) return "#FFFFFF"
    const lum = (h) => {
      const c = h.match(/../g).map((x) => {
        const v = parseInt(x, 16) / 255
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
      })
      return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }
    const ratio = (a, b) => (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    const l = lum(m)
    return ratio(l, lum("1a1a1a")) > ratio(l, lum("ffffff")) ? "#1A1A1A" : "#FFFFFF"
  }

  setRoot(primary, secondary) {
    const r = document.documentElement.style
    if (primary)   r.setProperty("--primary", primary)
    if (secondary) r.setProperty("--primary-2", secondary)
  }

  markActive(el) {
    this.swatchTargets.forEach((s) => (s.style.outline = s === el ? "3px solid var(--primary)" : "none"))
  }

  rootVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  }
}
