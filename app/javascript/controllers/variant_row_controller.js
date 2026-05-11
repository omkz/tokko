import { Controller } from "@hotwired/stimulus"

// Auto-submits the variant form when price/stock/active changes.
// Also supports explicit save button via form ID reference.
export default class extends Controller {
  autoSubmit(event) {
    const form = event.target.closest("form")
    if (form) {
      // Small debounce for number inputs
      clearTimeout(this._timer)
      this._timer = setTimeout(() => form.requestSubmit(), 400)
    }
  }
}
