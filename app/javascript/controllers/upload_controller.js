import { Controller } from "@hotwired/stimulus"

// Styled file upload: shows the chosen file name and a live image preview.
export default class extends Controller {
  static targets = ["input", "name", "preview"]

  pick() { this.inputTarget.click() }

  changed() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return
    if (this.hasNameTarget) this.nameTarget.textContent = file.name
    if (this.hasPreviewTarget && file.type.startsWith("image/")) {
      const url = URL.createObjectURL(file)
      this.previewTarget.innerHTML = `<img src="${url}" style="width:100%;height:100%;object-fit:cover;">`
    }
  }
}
