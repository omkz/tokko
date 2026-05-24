import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "manual", "textarea", "field"]

  select(event) {
    const address = event.currentTarget.dataset.address
    this.cardTargets.forEach(c => c.classList.remove("border-indigo-600", "bg-indigo-50/30"))
    event.currentTarget.classList.add("border-indigo-600", "bg-indigo-50/30")
    this.fieldTarget.value = address
    this.manualTarget.classList.add("hidden")
  }

  enterManually() {
    this.cardTargets.forEach(c => c.classList.remove("border-indigo-600", "bg-indigo-50/30"))
    this.fieldTarget.value = ""
    this.manualTarget.classList.remove("hidden")
    this.textareaTarget.focus()
  }

  syncField(event) {
    this.fieldTarget.value = event.currentTarget.value
  }
}
