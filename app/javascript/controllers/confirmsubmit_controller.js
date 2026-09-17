import { Controller } from "@hotwired/stimulus"

// Styled HTML confirmation before a form submits — for forms where Turbo is
// disabled (data-turbo=false), so data-turbo-confirm won't fire. Reuses the
// .l-confirm overlay styling.
const LABELS = {
  vi: { yes: "Tiếp tục thanh toán", no: "Huỷ" },
  en: { yes: "Continue to payment", no: "Cancel" },
}

export default class extends Controller {
  static values = { message: String }

  connect() { this.confirmed = false }

  check(event) {
    if (this.confirmed) { this.confirmed = false; return } // real submit passes through
    event.preventDefault()
    const L = LABELS[(document.documentElement.lang || "vi").slice(0, 2)] || LABELS.vi
    const form = this.element
    const overlay = document.createElement("div")
    overlay.className = "l-confirm-overlay"
    overlay.innerHTML = `
      <div class="l-confirm" role="dialog" aria-modal="true">
        <div class="l-confirm-icon">!</div>
        <div class="l-confirm-msg"></div>
        <div class="l-confirm-actions">
          <button type="button" class="l-btn l-btn-ghost" data-act="no"></button>
          <button type="button" class="l-btn l-btn-primary" data-act="yes"></button>
        </div>
      </div>`
    overlay.querySelector(".l-confirm-msg").textContent = this.messageValue
    overlay.querySelector('[data-act="no"]').textContent = L.no
    overlay.querySelector('[data-act="yes"]').textContent = L.yes
    document.body.appendChild(overlay)
    requestAnimationFrame(() => overlay.classList.add("open"))

    const close = () => { overlay.classList.remove("open"); setTimeout(() => overlay.remove(), 180) }
    overlay.querySelector('[data-act="yes"]').addEventListener("click", () => {
      this.confirmed = true; close()
      form.requestSubmit ? form.requestSubmit() : form.submit()
    })
    overlay.querySelector('[data-act="no"]').addEventListener("click", close)
    overlay.addEventListener("click", (e) => { if (e.target === overlay) close() })
  }
}
