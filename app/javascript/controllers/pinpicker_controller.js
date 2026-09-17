import { Controller } from "@hotwired/stimulus"
import { createMap, pinIcon } from "map_kit"

// The building form's map: resolves the typed address into a pin, and lets the
// landlord drag that pin onto the actual front door. A dragged pin is marked
// "manual" so the nightly/auto geocode never moves it back.
export default class extends Controller {
  static targets = ["map", "status", "lat", "lng", "source", "clear"]
  static values = {
    leafletJs: String, leafletCss: String, tileUrl: String, tileAttribution: String,
    lat: Number, lng: Number, url: String
  }

  async connect() {
    try {
      const { L, map } = await createMap(this, this.mapTarget)
      this.L = L
      this.map = map
      const start = this.hasPin ? [this.latValue, this.lngValue] : [16.05, 107.9]
      map.setView(start, this.hasPin ? 16 : 5)
      if (this.hasPin) this.placeMarker(start)
      requestAnimationFrame(() => map.invalidateSize())
      // Clicking the map is the fastest way to correct a pin on desktop.
      map.on("click", (e) => this.movePin([e.latlng.lat, e.latlng.lng], "manual"))
    } catch (e) {
      this.mapTarget.innerHTML = `<div class="mp-fail">${e.message}</div>`
    }
  }

  disconnect() {
    if (this.map) { this.map.remove(); this.map = null }
  }

  get hasPin() {
    return Number(this.latValue) !== 0 && Number(this.lngValue) !== 0
  }

  placeMarker(latlng) {
    const icon = pinIcon(this.L, `<span class="mp-dot"></span>`, "mp-pin")
    this.marker = this.L.marker(latlng, { icon, draggable: true }).addTo(this.map)
    this.marker.on("dragend", () => {
      const p = this.marker.getLatLng()
      this.write([p.lat, p.lng], "manual")
      this.say("Đã ghim thủ công — vị trí này sẽ được giữ nguyên.")
    })
  }

  movePin(latlng, source) {
    if (!this.map) return
    if (this.marker) this.marker.setLatLng(latlng)
    else this.placeMarker(latlng)
    this.map.setView(latlng, Math.max(this.map.getZoom(), 16))
    this.write(latlng, source)
    if (source === "manual") this.say("Đã ghim thủ công — vị trí này sẽ được giữ nguyên.")
  }

  write([lat, lng], source) {
    this.latTarget.value = lat.toFixed(7)
    this.lngTarget.value = lng.toFixed(7)
    this.sourceTarget.value = source
    if (this.hasClearTarget) this.clearTarget.hidden = false
  }

  // "Định vị theo địa chỉ" — asks the server to geocode whatever is currently
  // typed in the address fields, without saving the form first.
  async locate(event) {
    event.preventDefault()
    const button = event.currentTarget
    button.disabled = true
    this.say("Đang tìm vị trí…")
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
        },
        body: JSON.stringify(this.addressFields())
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "Không tìm được vị trí")
      this.movePin([data.lat, data.lng], "auto")
      this.say(data.approximate
        ? `Chỉ tìm được vị trí tương đối (${data.label}). Hãy kéo ghim tới đúng chỗ.`
        : `Đã định vị: ${data.label}`)
    } catch (e) {
      this.say(e.message)
    } finally {
      button.disabled = false
    }
  }

  // Back to "let the address decide": clears the pin so the background geocode
  // takes over again after saving.
  reset(event) {
    event.preventDefault()
    if (this.marker) { this.marker.remove(); this.marker = null }
    this.latTarget.value = ""
    this.lngTarget.value = ""
    this.sourceTarget.value = ""
    if (this.hasClearTarget) this.clearTarget.hidden = true
    this.say("Đã bỏ ghim — hệ thống sẽ tự định vị lại theo địa chỉ sau khi lưu.")
  }

  addressFields() {
    const value = (name) => this.form?.querySelector(`[name="building[${name}]"]`)?.value || ""
    return {
      address_line: value("address_line"), ward: value("ward"),
      district: value("district"), city: value("city")
    }
  }

  get form() { return this.element.closest("form") }

  say(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
