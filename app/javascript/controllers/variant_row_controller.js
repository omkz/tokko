import { Controller } from "@hotwired/stimulus"

// Auto-submits the variant form when price/stock/active changes.
// Also supports explicit save button via form ID reference.
export default class extends Controller {
  static targets = ["indicator"]

  autoSubmit(event) {
    const form = event.target.closest("form")
    if (form) {
      if (this.hasIndicatorTarget) this.indicatorTarget.classList.remove("hidden")
      
      clearTimeout(this._timer)
      this._timer = setTimeout(() => {
        form.requestSubmit()
      }, 400)
    }
  }

  onPostSubmit() {
    if (this.hasIndicatorTarget) {
      // Keep indicator for a brief moment to show success
      setTimeout(() => {
        this.indicatorTarget.classList.add("hidden")
      }, 500)
    }
  }
}
