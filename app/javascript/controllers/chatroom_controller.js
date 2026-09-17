import { Controller } from "@hotwired/stimulus"

// Keeps the chat scrolled to the newest message, previews pending attachments,
// and clears the composer after send. New messages arrive live via
// turbo_stream_from (Turbo appends to #messages).
export default class extends Controller {
  static targets = ["scroll", "input", "form", "file", "atts", "send"]
  static values = { updatesUrl: String, msgPath: String }

  connect() {
    this.markMine()
    // Land on the newest message with no visible jump: keep the list hidden
    // until we've scrolled to the bottom on the next frame.
    this.scrollTarget.style.visibility = "hidden"
    this.scrollToBottom()
    requestAnimationFrame(() => {
      this.scrollToBottom()
      this.scrollTarget.style.visibility = ""
    })
    // Images change the height as they load — re-pin to the bottom.
    this.scrollTarget.querySelectorAll("img").forEach((img) => {
      if (!img.complete) img.addEventListener("load", () => this.scrollToBottom(), { once: true })
    })
    this.observer = new MutationObserver(() => { this.dedupe(); this.markMine(); this.scrollToBottom() })
    this.observer.observe(this.scrollTarget, { childList: true })
    this.startPolling()
  }

  // Mark each message as "mine" (the viewer's own) vs. someone else's. For a
  // tenant we compare the actual sender member, so a co-tenant's message stays
  // on the left with their name. Runs for broadcast/polled messages too.
  markMine() {
    const as = this.element.dataset.as
    const vm = this.element.dataset.viewerMember
    this.scrollTarget.querySelectorAll(".msg").forEach((el) => {
      const sk = el.dataset.sk
      const mine = as === "landlord" ? sk === "landlord" : (sk === "tenant" && vm && el.dataset.sm === vm)
      el.classList.toggle("msg--mine", !!mine)
    })
  }

  // Fallback for when the /cable WebSocket is unavailable (e.g. a proxy that
  // doesn't upgrade WebSockets): poll for messages newer than the last one we
  // have. No-ops whenever the Turbo cable stream is actually connected, so once
  // WebSockets work this costs nothing. dedupe() guards against double-adds.
  startPolling() {
    if (!this.hasUpdatesUrlValue || !this.updatesUrlValue) return
    this.poll = setInterval(() => this.pollOnce(), 5000)
  }

  pollOnce() {
    const src = document.querySelector("turbo-cable-stream-source")
    if (src && src.hasAttribute("connected")) return   // realtime is live
    if (document.hidden) return
    fetch(`${this.updatesUrlValue}?after=${this.lastId()}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }, credentials: "same-origin"
    })
      .then((r) => (r.ok ? r.text() : ""))
      .then((html) => { if (html && html.trim()) window.Turbo.renderStreamMessage(html) })
      .catch(() => {})
  }

  lastId() {
    const ids = Array.from(this.scrollTarget.querySelectorAll("[id^='message_']"))
      .map((e) => parseInt(e.id.replace("message_", ""), 10) || 0)
    return ids.length ? Math.max(...ids) : 0
  }

  // The sender gets their message from the POST response AND (when the WebSocket
  // is connected) the broadcast — keep only the first node per message id.
  dedupe() {
    const seen = new Set()
    this.scrollTarget.querySelectorAll("[id^='message_']").forEach((el) => {
      if (seen.has(el.id)) el.remove()
      else seen.add(el.id)
    })
  }

  disconnect() { this.observer?.disconnect(); if (this.poll) clearInterval(this.poll) }

  // ---- Edit / delete own message (server broadcasts the DOM change) ----
  _msgId(el) { const m = el.closest(".msg"); return m ? m.id.replace("message_", "") : null }
  _url(id) { return (this.msgPathValue || "").replace("MSGID", id) }

  async deleteMsg(e) {
    const id = this._msgId(e.currentTarget)
    if (!id || !this.msgPathValue) return
    if (!confirm("Xoá tin nhắn này?")) return
    await this._req(this._url(id), "DELETE")
    e.currentTarget.closest(".msg")?.remove() // instant feedback; broadcast confirms
  }

  async editMsg(e) {
    const id = this._msgId(e.currentTarget)
    if (!id || !this.msgPathValue) return
    const body = e.currentTarget.closest(".msg")?.querySelector(".msg-body")
    const cur = body ? body.textContent.trim() : ""
    const val = prompt("Sửa tin nhắn:", cur)
    if (val == null || !val.trim()) return
    await this._req(this._url(id), "PATCH", { body: val.trim() })
  }

  async _req(url, method, payload) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      await fetch(url, {
        method, credentials: "same-origin",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token || "" },
        body: payload ? JSON.stringify(payload) : null,
      })
    } catch (e) {}
  }

  // Don't submit an empty message (no text and no files).
  guard(event) {
    const hasText = this.hasInputTarget && this.inputTarget.value.trim().length > 0
    const hasFiles = this.hasFileTarget && this.fileTarget.files.length > 0
    if (!hasText && !hasFiles) event.preventDefault()
  }

  // Show the send button only when there is text or an attachment (Zalo-style).
  toggleSend() {
    if (!this.hasSendTarget) return
    const hasText = this.hasInputTarget && this.inputTarget.value.trim().length > 0
    const hasFiles = this.hasFileTarget && this.fileTarget.files.length > 0
    this.sendTarget.hidden = !(hasText || hasFiles)
  }

  filesPicked() {
    this.toggleSend()
    if (!this.hasAttsTarget) return
    const files = Array.from(this.fileTarget.files || [])
    this.attsTarget.innerHTML = ""
    this.attsTarget.hidden = files.length === 0
    files.forEach((f) => {
      const chip = document.createElement("div")
      chip.className = "att"
      if (f.type.startsWith("image/")) {
        const img = document.createElement("img")
        img.src = URL.createObjectURL(f)
        chip.appendChild(img)
      } else {
        const ic = document.createElement("span")
        ic.textContent = "📄"
        chip.appendChild(ic)
      }
      const name = document.createElement("span")
      name.textContent = f.name
      chip.appendChild(name)
      this.attsTarget.appendChild(chip)
    })
  }

  sent(event) {
    if (event.detail?.success !== false) {
      if (this.hasInputTarget) { this.inputTarget.value = ""; this.inputTarget.focus() }
      if (this.hasFileTarget) this.fileTarget.value = ""
      if (this.hasAttsTarget) { this.attsTarget.innerHTML = ""; this.attsTarget.hidden = true }
      this.toggleSend()
    }
  }

  scrollToBottom() {
    this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight
  }
}
