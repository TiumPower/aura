import { Controller } from "@hotwired/stimulus"

// Shows the building / unit picker matching the selected send-scope.
export default class extends Controller {
  static targets = ["scope", "buildings", "units"]

  connect() { this.toggle() }

  toggle() {
    const scope = this.scopeTargets.find((r) => r.checked)?.value || "all"
    if (this.hasBuildingsTarget) this.buildingsTarget.hidden = scope !== "buildings"
    if (this.hasUnitsTarget) this.unitsTarget.hidden = scope !== "units"
  }
}
