import { Controller } from "@hotwired/stimulus"

// Social share helpers for the social_share mission.
//   openPlatform → copy the shop link AND open the chosen network, so the user
//     can paste it into a post (Zalo / Instagram / TikTok have no pre-filled web
//     share; Facebook opens its sharer directly).
//   copy    → just copy the link.
//   native  → device share sheet (fallback).
export default class extends Controller {
  static targets = ["copyLabel", "status"]
  static values = { url: String, text: String }

  openPlatform(event) {
    const href = event.currentTarget.dataset.shareHref
    // Open synchronously inside the click so the popup isn't blocked.
    if (href) window.open(href, "_blank", "noopener")
    this._writeClipboard()
    this._flashStatus()
  }

  async native() {
    const data = { title: this.textValue, text: this.textValue, url: this.urlValue }
    if (navigator.share) {
      try { await navigator.share(data) } catch (e) { /* user cancelled */ }
    } else {
      this.copy()
    }
  }

  copy() {
    this._writeClipboard()
    if (this.hasCopyLabelTarget) {
      const el = this.copyLabelTarget, prev = el.textContent
      el.textContent = "✓ Đã copy"
      setTimeout(() => { el.textContent = prev }, 1600)
    }
    this._flashStatus()
  }

  _writeClipboard() {
    try {
      navigator.clipboard.writeText(this.urlValue).catch(() => this._prompt())
    } catch (e) {
      this._prompt()
    }
  }

  _prompt() { window.prompt("Sao chép link:", this.urlValue) }

  _flashStatus() {
    if (this.hasStatusTarget) this.statusTarget.hidden = false
  }
}
