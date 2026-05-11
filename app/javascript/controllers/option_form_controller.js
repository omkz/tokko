import { Controller } from "@hotwired/stimulus"

// Handles the "Add Option" form:
// - Parses comma-separated values into a live tag preview
// - Injects hidden fields before form submit
export default class extends Controller {
  static targets = ["hiddenValues", "preview"]

  parseValues(event) {
    const raw = event.target.value
    const values = raw.split(",").map(v => v.trim()).filter(v => v.length > 0)

    // Update preview tags
    this.previewTarget.innerHTML = values.map(v =>
      `<span class="inline-flex items-center bg-indigo-50 text-indigo-700 text-xs font-medium px-2.5 py-1 rounded-full">${v}</span>`
    ).join("")

    // Inject hidden fields for nested attributes
    this.hiddenValuesTarget.innerHTML = values.map((v, i) =>
      `<input type="hidden" name="product_option[product_option_values_attributes][${i}][value]" value="${v}">
       <input type="hidden" name="product_option[product_option_values_attributes][${i}][position]" value="${i + 1}">`
    ).join("")
  }
}
