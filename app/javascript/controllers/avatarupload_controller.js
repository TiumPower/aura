import { Controller } from "@hotwired/stimulus"

// Click the avatar to pick an image, preview it instantly, then reveal a Save
// button (avatar is saved on its own, separate from the profile form).
export default class extends Controller {
  static targets = ["input", "box", "save"]

  change() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return
    const url = URL.createObjectURL(file)
    this.boxTarget.innerHTML = `<img src="${url}" style="width:100%;height:100%;object-fit:cover;">`
    if (this.hasSaveTarget) this.saveTarget.style.display = "inline-flex"
  }
}
