import { Controller } from "@hotwired/stimulus"

// A styled photo dropzone: click the box to pick files, shows count + thumbnails.
export default class extends Controller {
  static targets = ["input", "hint", "preview"]
  static values = { submitOnChange: Boolean }

  open() { this.inputTarget.click() }

  changed() {
    const files = Array.from(this.inputTarget.files || [])
    if (this.hasHintTarget) {
      this.hintTarget.textContent = files.length
        ? `Đã chọn ${files.length} ảnh${this.submitOnChangeValue ? " — đang tải lên…" : " — bấm để chọn lại"}`
        : "Bấm để chọn ảnh, hoặc kéo thả vào đây"
    }
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = ""
      files.slice(0, 12).forEach((f) => {
        const img = document.createElement("img")
        img.src = URL.createObjectURL(f)
        this.previewTarget.appendChild(img)
      })
    }
    if (this.submitOnChangeValue && files.length) {
      this.element.closest("form")?.requestSubmit()
    }
  }

  dragover(e) { e.preventDefault(); this.element.dataset.drag = "1" }
  dragleave() { delete this.element.dataset.drag }
  drop(e) {
    e.preventDefault()
    delete this.element.dataset.drag
    this.inputTarget.files = e.dataTransfer.files
    this.changed()
  }
}
