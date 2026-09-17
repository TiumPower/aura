import { loadLeaflet } from "leaflet_loader"

// Shared bits for every map on the site, so the public map, the room page and
// the landlord's pin picker all look and behave the same.
export async function createMap(controller, element, options = {}) {
  const L = await loadLeaflet(controller.leafletJsValue, controller.leafletCssValue)
  const map = L.map(element, {
    scrollWheelZoom: false, // a map shouldn't hijack the page scroll
    zoomControl: true,
    ...options
  })
  L.tileLayer(controller.tileUrlValue, {
    maxZoom: 19,
    attribution: controller.tileAttributionValue
  }).addTo(map)
  // Wheel zoom once the visitor has actually engaged with the map.
  map.on("click", () => map.scrollWheelZoom.enable())
  return { L, map }
}

// Markers are plain HTML (divIcon) instead of Leaflet's default PNG pins: it
// keeps the price readable at a glance and avoids shipping the icon sprites.
export function pinIcon(L, html, className = "mp-pin") {
  return L.divIcon({ html, className, iconSize: null })
}

// "4500000" → "4,5 tr" — a price label has to fit inside a map pin.
export function shortPrice(vnd) {
  const n = Number(vnd) || 0
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(1).replace(".0", "").replace(".", ",")} tỷ`
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(".0", "").replace(".", ",")} tr`
  if (n >= 1_000) return `${Math.round(n / 1000)}k`
  return String(n)
}
