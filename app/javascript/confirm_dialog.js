// Styled HTML confirmation for any element with data-turbo-confirm="…",
// replacing the browser's native confirm(). Themes via CSS variables.
// Button labels follow the page locale (<html lang> is set to I18n.locale in
// every layout), so the customer app's EN mode shows Cancel/OK.
const LABELS = {
  vi: { yes: "Đồng ý", no: "Huỷ", sure: "Bạn chắc chắn?" },
  en: { yes: "OK", no: "Cancel", sure: "Are you sure?" },
};

(function () {
  function ask(message) {
    return new Promise((resolve) => {
      const lang = (document.documentElement.lang || "vi").slice(0, 2)
      const L = LABELS[lang] || LABELS.vi
      const overlay = document.createElement("div")
      overlay.className = "l-confirm-overlay"
      overlay.innerHTML = `
        <div class="l-confirm" role="dialog" aria-modal="true">
          <div class="l-confirm-icon">?</div>
          <div class="l-confirm-msg"></div>
          <div class="l-confirm-actions">
            <button type="button" class="l-btn l-btn-ghost" data-act="no"></button>
            <button type="button" class="l-btn l-btn-primary" data-act="yes"></button>
          </div>
        </div>`
      overlay.querySelector('[data-act="no"]').textContent = L.no
      overlay.querySelector('[data-act="yes"]').textContent = L.yes
      overlay.querySelector(".l-confirm-msg").textContent = message || L.sure
      document.body.appendChild(overlay)
      requestAnimationFrame(() => overlay.classList.add("open"))

      const done = (val) => {
        overlay.classList.remove("open")
        setTimeout(() => overlay.remove(), 180)
        resolve(val)
      }
      overlay.querySelector('[data-act="yes"]').addEventListener("click", () => done(true))
      overlay.querySelector('[data-act="no"]').addEventListener("click", () => done(false))
      overlay.addEventListener("click", (e) => { if (e.target === overlay) done(false) })
      document.addEventListener("keydown", function esc(e) {
        if (e.key === "Escape") { done(false); document.removeEventListener("keydown", esc) }
      })
      overlay.querySelector('[data-act="yes"]').focus()
    })
  }

  const install = () => {
    if (window.Turbo) window.Turbo.setConfirmMethod(ask)
  }
  install()
  document.addEventListener("turbo:load", install, { once: true })
})()
