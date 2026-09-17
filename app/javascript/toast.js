// Turbo-proof toasts. The server stashes flash messages in a JS-readable
// `toast` cookie on redirect; here we build the toast AFTER Turbo's final
// render (turbo:load), so it never gets lost in Turbo's snapshot/visit cycle.
const LABELS = { close: "Đóng" }

function readToastCookie() {
  const m = document.cookie.match(/(?:^|;\s*)toast=([^;]*)/)
  if (!m) return null
  // clear immediately so it shows once
  document.cookie = "toast=; Max-Age=0; path=/"
  // Rack encodes spaces as "+" in the cookie; decodeURIComponent leaves those, so
  // convert them back before parsing.
  try { return JSON.parse(decodeURIComponent(m[1].replace(/\+/g, " "))) } catch (e) { return null }
}

function addToast(wrap, msg, isError) {
  const el = document.createElement("div")
  el.className = "l-toast" + (isError ? " error" : "")
  el.innerHTML = `<span class="ic">${isError ? "!" : "✓"}</span><div class="msg"></div>` +
                 `<button type="button" class="x" aria-label="${LABELS.close}">✕</button>`
  el.querySelector(".msg").textContent = msg
  wrap.appendChild(el)
  const dismiss = () => {
    el.classList.add("leaving")
    setTimeout(() => { el.remove(); if (!wrap.childElementCount) wrap.remove() }, 320)
  }
  const timer = setTimeout(dismiss, 4000)
  el.querySelector(".x").addEventListener("click", () => { clearTimeout(timer); dismiss() })
}

function showToasts() {
  const data = readToastCookie()
  if (!data || (!data.notice && !data.alert)) return
  let wrap = document.querySelector(".l-toast-wrap")
  if (!wrap) { wrap = document.createElement("div"); wrap.className = "l-toast-wrap"; document.body.appendChild(wrap) }
  if (data.notice) addToast(wrap, data.notice, false)
  if (data.alert) addToast(wrap, data.alert, true)
}

document.addEventListener("DOMContentLoaded", showToasts)
document.addEventListener("turbo:load", showToasts)
