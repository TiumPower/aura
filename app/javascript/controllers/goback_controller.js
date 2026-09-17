import { Controller } from "@hotwired/stimulus"

// Back link that returns to the actual previous page (browser history),
// falling back to the element's href when there's no history to go back to.
export default class extends Controller {
  back(e) {
    if (window.history.length > 1) {
      e.preventDefault()
      window.history.back()
    }
  }
}
