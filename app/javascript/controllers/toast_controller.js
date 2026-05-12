import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Auto-remove toast after 3 seconds
    setTimeout(() => {
      this.close()
    }, 3000)
  }

  close() {
    // Animate out
    this.element.classList.add("translate-x-full", "opacity-0")
    
    // Remove from DOM after animation finishes
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }
}
