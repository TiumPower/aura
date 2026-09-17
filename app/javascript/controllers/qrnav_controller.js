import { Controller } from "@hotwired/stimulus"

// Member multi-purpose scanner. Reads a QR (URL or bare token) and navigates to
// the resolve endpoint, which auto-detects promo-claim vs POS-earn.
export default class extends Controller {
  static targets = ["video", "status", "overlay"]
  static values = { resolveUrl: String }

  async connect() {
    // Ask the browser what the real camera-permission state is. When it's
    // already "granted" we auto-start with no prompt; when it's "prompt" we
    // keep the overlay so getUserMedia fires on the user's tap (fewer surprise
    // prompts, and iOS is happier). "denied" shows how to re-enable. When the
    // Permissions API can't answer (Safari/iOS often can't for camera) we fall
    // back to the localStorage heuristic.
    const state = await this.cameraState()
    if (state === "granted") {
      if (this.hasOverlayTarget) this.overlayTarget.style.display = "none"
      this.start()
    } else if (state === "denied") {
      if (this.hasOverlayTarget) this.overlayTarget.style.display = ""
      this.statusTarget.textContent = "Camera đang bị chặn — hãy bật lại quyền camera trong cài đặt trình duyệt, hoặc nhập mã bên dưới."
    } else if (state === "prompt") {
      if (this.hasOverlayTarget) this.overlayTarget.style.display = ""
    } else {
      if (this.cameraSeen() && this.hasOverlayTarget) this.overlayTarget.style.display = "none"
      this.start()
    }
    this.watchPermission()
  }

  async cameraState() {
    try {
      if (navigator.permissions?.query) {
        this._perm = await navigator.permissions.query({ name: "camera" })
        return this._perm.state // "granted" | "prompt" | "denied"
      }
    } catch (e) { /* camera not a queryable name (iOS/Safari) */ }
    return null
  }

  // Auto-start the moment the user grants access from the browser UI.
  watchPermission() {
    if (!this._perm) return
    this._perm.onchange = () => {
      if (this._perm.state === "granted" && !this.stream) { this.start() }
    }
  }

  cameraSeen() { try { return localStorage.getItem("qrnavCameraOk") === "1" } catch (e) { return false } }
  rememberCamera(ok) { try { ok ? localStorage.setItem("qrnavCameraOk", "1") : localStorage.removeItem("qrnavCameraOk") } catch (e) {} }

  async start() {
    if (!navigator.mediaDevices?.getUserMedia) {
      this.statusTarget.textContent = "Trình duyệt không hỗ trợ camera — hãy nhập mã bên dưới."
      return
    }
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } })
      this.videoTarget.srcObject = this.stream
      this.videoTarget.setAttribute("playsinline", "true")
      await this.videoTarget.play()
      if (this.hasOverlayTarget) this.overlayTarget.style.display = "none"
      this.rememberCamera(true)

      if ("BarcodeDetector" in window) {
        this.mode = "native"
        this.detector = new BarcodeDetector({ formats: ["qr_code"] })
      } else {
        // Fallback for iOS/older browsers: decode frames with jsQR.
        this.mode = "jsqr"
        this.jsqr = (await import("jsqr")).default || window.jsQR
        this.canvas = document.createElement("canvas")
      }
      this.statusTarget.textContent = "Đang quét…"
      this.timer = setInterval(() => this.tick(), this.mode === "jsqr" ? 250 : 400)
    } catch (e) {
      // Access failed/denied — restore the overlay button so the user can retry.
      this.rememberCamera(false)
      if (this.hasOverlayTarget) this.overlayTarget.style.display = ""
      this.statusTarget.textContent = "Không truy cập được camera — hãy nhập mã bên dưới."
    }
  }

  async tick() {
    try {
      if (this.mode === "native") {
        const codes = await this.detector.detect(this.videoTarget)
        if (codes.length) { this.stop(); this.go(codes[0].rawValue) }
      } else {
        const v = this.videoTarget
        if (!v.videoWidth) return
        this.canvas.width = v.videoWidth
        this.canvas.height = v.videoHeight
        const ctx = this.canvas.getContext("2d", { willReadFrequently: true })
        ctx.drawImage(v, 0, 0, this.canvas.width, this.canvas.height)
        const img = ctx.getImageData(0, 0, this.canvas.width, this.canvas.height)
        const res = this.jsqr(img.data, img.width, img.height, { inversionAttempts: "dontInvert" })
        if (res && res.data) { this.stop(); this.go(res.data) }
      }
    } catch (e) { /* transient */ }
  }

  go(value) {
    value = (value || "").trim()
    try {
      const u = new URL(value)
      if (u.origin === location.origin) { window.location.href = value; return }
    } catch (e) { /* not a URL */ }
    window.location.href = `${this.resolveUrlValue}?code=${encodeURIComponent(value)}`
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    if (this.stream) this.stream.getTracks().forEach((t) => t.stop())
  }

  disconnect() { this.stop() }
}
