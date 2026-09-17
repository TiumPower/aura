import { Controller } from "@hotwired/stimulus"

// Bill VietQR: view it big, save it, share it, or copy the account number.
//
// Saving an image from a standalone PWA is the awkward part — `window.open` is
// often swallowed and an <a download> is ignored on iOS. So the reliable path is
// to show a real PNG the user can long-press ("Save image"), with the Web Share
// sheet and a blob download as the other two routes.
export default class extends Controller {
  static targets = ["overlay", "bigImg", "saveBtn", "acctBtn"]
  static values = {
    url: String, download: String, name: String,
    account: String, amount: Number, desc: String
  }

  open() {
    if (!this.hasOverlayTarget) return
    // Set src on first open so the big PNG isn't fetched until it's needed.
    if (this.hasBigImgTarget && !this.bigImgTarget.getAttribute("src")) {
      this.bigImgTarget.src = this.urlValue
    }
    this.overlayTarget.hidden = false
    document.body.style.overflow = "hidden"
  }

  close() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.hidden = true
    document.body.style.overflow = ""
  }

  backdrop(e) { if (e.target === this.overlayTarget) this.close() }

  async share() {
    const file = await this.#file()
    if (file && navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: "Mã QR chuyển khoản" })
        return
      } catch (e) {
        if (e?.name === "AbortError") return // user dismissed the sheet
      }
    }
    this.save()
  }

  async save() {
    const blob = await this.#blob()
    if (!blob) { window.open(this.downloadValue || this.urlValue, "_blank"); return }
    const href = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = href
    a.download = `${this.nameValue || "vietqr"}.png`
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(href), 10000)
    this.#flash(this.saveBtnTarget, "✓ Đã lưu")
  }

  copyAccount() {
    this.#copy(this.accountValue, this.acctBtnTarget)
  }

  // ---- helpers ----------------------------------------------------------
  async #blob() {
    try {
      const res = await fetch(this.urlValue, { credentials: "same-origin" })
      return res.ok ? await res.blob() : null
    } catch { return null }
  }

  async #file() {
    const blob = await this.#blob()
    if (!blob) return null
    return new File([blob], `${this.nameValue || "vietqr"}.png`, { type: "image/png" })
  }

  async #copy(text, btn) {
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const ta = document.createElement("textarea")
      ta.value = text
      ta.style.position = "fixed"
      ta.style.opacity = "0"
      document.body.appendChild(ta)
      ta.select()
      try { document.execCommand("copy") } catch { /* give up quietly */ }
      ta.remove()
    }
    this.#flash(btn, "✓ Đã chép")
  }

  #flash(btn, label) {
    if (!btn) return
    const prev = btn.innerHTML
    btn.innerHTML = label
    setTimeout(() => { btn.innerHTML = prev }, 1600)
  }
}
