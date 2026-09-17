import { Controller } from "@hotwired/stimulus"

// Thanh tab cuộn ngang giữ đúng vị trí giữa các lần điều hướng.
//
// Mỗi lần bấm tab là một lần tải trang, nên thanh tab dựng lại ở scrollLeft 0:
// bấm "Chia sẻ & QR" xong thì thanh nhảy về đầu và tab đang mở nằm ngoài khung —
// đúng cảm giác "chạy lung tung" so với app thật.
//
// Cố tình KHÔNG dùng scrollIntoView: nó cuộn cả trang theo trục dọc, nên trên
// điện thoại màn hình giật xuống mỗi lần đổi tab.
export default class extends Controller {
  // Các dải chip/tab trong app đánh dấu mục đang chọn bằng .active hoặc .on.
  static values = { key: String, activeSelector: { type: String, default: ".active, .on, [aria-current=page]" } }

  connect() {
    const box = this.element
    // Khôi phục vị trí cũ trước, để thanh không loé từ 0 sang chỗ khác.
    const saved = this.load()
    if (saved != null) box.scrollLeft = saved

    const active = box.querySelector(this.activeSelectorValue)
    if (active) {
      const a = active.getBoundingClientRect()
      const b = box.getBoundingClientRect()
      // Chỉ can thiệp khi tab đang mở bị che, và canh vào giữa khung.
      if (a.left < b.left + 8 || a.right > b.right - 8) {
        box.scrollLeft += (a.left - b.left) - (box.clientWidth - a.width) / 2
      }
    }

    this.save = () => this.store(box.scrollLeft)
    box.addEventListener("scroll", this.save, { passive: true })
  }

  disconnect() {
    if (this.save) this.element.removeEventListener("scroll", this.save)
  }

  get storageKey() { return `hscroll:${this.keyValue || this.element.className}` }

  store(value) {
    try { sessionStorage.setItem(this.storageKey, value) } catch (e) { /* private mode */ }
  }

  load() {
    try {
      const raw = sessionStorage.getItem(this.storageKey)
      return raw == null ? null : parseFloat(raw)
    } catch (e) { return null }
  }
}
