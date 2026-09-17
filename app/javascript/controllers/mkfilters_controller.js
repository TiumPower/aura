import { Controller } from "@hotwired/stimulus"

// Marketplace filter row. The AI pre-fills these controls, so changing one is an
// explicit correction: we flag the search as "refined" and submit, which tells
// the server to trust these values instead of re-deriving them from the text.
export default class extends Controller {
  static targets = ["am", "refined", "city"]

  apply(e) {
    // "+ Tiện nghi" is an adder, not a filter value: fold it into the list.
    if (e?.target?.name === "add_amenity" && e.target.value) {
      const list = this.#amenities()
      if (!list.includes(e.target.value)) list.push(e.target.value)
      this.amTarget.value = list.join("|")
      e.target.value = ""
    }
    this.#submit()
  }

  dropAmenity(e) {
    const drop = e.currentTarget.dataset.amenity
    this.amTarget.value = this.#amenities().filter((a) => a !== drop).join("|")
    this.#submit()
  }

  dropCity() {
    if (this.hasCityTarget) this.cityTarget.value = ""
    this.#submit()
  }

  reset() {
    const form = this.element.closest("form")
    form.querySelectorAll("select").forEach((s) => { s.value = "" })
    if (this.hasCityTarget) this.cityTarget.value = ""
    this.amTarget.value = ""
    this.#submit()
  }

  #amenities() {
    return this.amTarget.value.split("|").filter(Boolean)
  }

  #submit() {
    this.refinedTarget.disabled = false // only sent when the user actually adjusts a filter
    this.element.closest("form").requestSubmit()
  }
}
