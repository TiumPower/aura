import { Controller } from "@hotwired/stimulus"

// Global bottom progress bar for async banner generation. Polls the workspace's
// banner jobs and shows an estimated % while generating (image-gen gives no real
// progress), then a clickable "done" notice — visible on any merchant page.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.acked = this.loadAcked()
    this.poll()
    this.timer = setInterval(() => this.poll(), 5000)
    // Smoothly animate the estimated bar between polls.
    this.tick = setInterval(() => this.render(), 1000)
  }

  disconnect() { clearInterval(this.timer); clearInterval(this.tick) }

  async poll() {
    try {
      const resp = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!resp.ok) return
      this.jobs = (await resp.json()).jobs || []
      this._t = Date.now()
      this.render()
    } catch (e) { /* keep last state */ }
  }

  render() {
    const jobs = this.jobs || []
    const generating = jobs.filter((j) => j.status === "generating")
    const done = jobs.filter((j) => (j.status === "ready" || j.status === "failed") && !this.acked.has(this.key(j)))

    if (!generating.length && !done.length) { this.element.innerHTML = ""; return }

    let html = ""
    generating.forEach((j) => {
      const pct = Math.min(96, Math.round((j.elapsed + this.since(j)) / 40 * 100))
      html += this.row(`
        <div style="flex:1; min-width:0;">
          <div style="font-size:12px; font-weight:700; color:var(--ink);">🎨 Đang tạo banner AI — ${this.esc(j.name)}</div>
          <div style="height:8px; border-radius:999px; background:var(--surface-2); overflow:hidden; margin-top:6px;">
            <div style="height:100%; width:${pct}%; background:var(--primary); border-radius:999px; transition:width .8s ease;"></div>
          </div>
        </div>
        <div style="font-variant-numeric:tabular-nums; font-weight:700; color:var(--primary); min-width:44px; text-align:right;">${pct}%</div>
      `)
    })
    done.forEach((j) => {
      const ok = j.status === "ready"
      html += this.row(`
        <div style="flex:1; min-width:0; font-size:13px; font-weight:700; color:${ok ? "var(--good, #2e7d5b)" : "var(--warn, #B4402F)"};">
          ${ok ? "✅ Banner đã tạo xong" : "⚠️ Tạo banner thất bại"} — ${this.esc(j.name)}
        </div>
        ${ok ? `<a href="${j.url}" data-job-id="${this.key(j)}" data-action="jobbar#open" style="flex:none; background:var(--primary); color:#fff; text-decoration:none; padding:8px 14px; border-radius:10px; font-weight:700; font-size:13px;">Xem →</a>` : ""}
        <button type="button" data-job-id="${this.key(j)}" data-action="jobbar#dismiss" style="flex:none; background:none; border:none; color:var(--ink-2); cursor:pointer; font-size:18px; line-height:1;">×</button>
      `)
    })
    this.element.innerHTML = html
  }

  row(inner) {
    return `<div style="pointer-events:auto; width:100%; background:#fff; border:1px solid var(--line); border-radius:14px; box-shadow:0 10px 30px rgba(0,0,0,.16); padding:12px 14px; display:flex; align-items:center; gap:12px;">${inner}</div>`
  }

  open(e) { this.ack(e.currentTarget.dataset.jobId) }      // navigates via href; mark seen
  dismiss(e) { e.preventDefault(); this.ack(e.currentTarget.dataset.jobId); this.render() }

  ack(key) { this.acked.add(key); this.saveAcked() }
  key(j) { return `${j.id}:${j.requested_at || 0}` }
  since(j) { return this._t ? (Date.now() - this._t) / 1000 : 0 } // seconds since last poll, approx
  esc(s) { const d = document.createElement("div"); d.textContent = s; return d.innerHTML }

  loadAcked() { try { return new Set(JSON.parse(localStorage.getItem("bannerjob:acked") || "[]")) } catch (e) { return new Set() } }
  saveAcked()  { try { localStorage.setItem("bannerjob:acked", JSON.stringify([...this.acked].slice(-50))) } catch (e) {} }
}
