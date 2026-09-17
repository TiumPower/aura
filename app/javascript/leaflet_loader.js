// Loads the vendored Leaflet build (JS + CSS) the first time a map appears on
// the page, and hands every caller the same promise. Maps are a minority of
// pages, so 150 KB of mapping library shouldn't ride along in the main bundle.
let pending = null

export function loadLeaflet(jsUrl, cssUrl) {
  if (window.L) return Promise.resolve(window.L)
  if (pending) return pending

  pending = new Promise((resolve, reject) => {
    if (cssUrl && !document.querySelector("link[data-leaflet]")) {
      const link = document.createElement("link")
      link.rel = "stylesheet"
      link.href = cssUrl
      link.dataset.leaflet = "1"
      document.head.appendChild(link)
    }
    const script = document.createElement("script")
    script.src = jsUrl
    script.onload = () => resolve(window.L)
    script.onerror = () => {
      pending = null
      reject(new Error("Không tải được thư viện bản đồ"))
    }
    document.head.appendChild(script)
  })
  return pending
}
