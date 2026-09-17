import { Controller } from "@hotwired/stimulus"

// Keeps the sidebar steady across Turbo navigations. Each navigation re-renders
// the sidebar at scrollTop 0, which makes it visibly jump to the top — most
// noticeably when opening a page with no active nav item (e.g. Account/profile,
// whose link lives in the footer). We restore the last scroll position, then
// only nudge if the active item is off-screen.
export default class extends Controller {
  static KEY = "l-side-scroll"

  connect() {
    const c = this.element

    // 1) Restore where the sidebar was before this navigation.
    try {
      const saved = sessionStorage.getItem(this.constructor.KEY)
      if (saved != null) c.scrollTop = parseFloat(saved)
    } catch (e) { /* private mode */ }

    // 2) Make sure the active item is comfortably visible; otherwise centre it.
    const active = c.querySelector(".l-nav-item.active")
    if (active) {
      const r = active.getBoundingClientRect()
      const cr = c.getBoundingClientRect()
      if (!(r.top >= cr.top + 8 && r.bottom <= cr.bottom - 8)) {
        c.scrollTop += (r.top - cr.top) - (c.clientHeight - r.height) / 2
      }
    }

    // 3) Track scroll so the next navigation can restore it.
    this._save = () => { try { sessionStorage.setItem(this.constructor.KEY, c.scrollTop) } catch (e) {} }
    c.addEventListener("scroll", this._save, { passive: true })
  }

  disconnect() {
    if (this._save) this.element.removeEventListener("scroll", this._save)
  }
}
