import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["price", "variantId", "button"]
  static values = { variants: Array }

  selectOption(event) {
    const value = event.currentTarget.dataset.value
    const optionName = event.currentTarget.dataset.option
    
    // Toggle active state on buttons
    const group = event.currentTarget.parentElement
    group.querySelectorAll('button').forEach(btn => btn.classList.remove('border-indigo-600', 'text-indigo-600', 'ring-2', 'ring-indigo-100'))
    event.currentTarget.classList.add('border-indigo-600', 'text-indigo-600', 'ring-2', 'ring-indigo-100')

    this.updateSelection()
  }

  updateSelection() {
    const selectedOptions = {}
    document.querySelectorAll('[data-option]').forEach(btn => {
      if (btn.classList.contains('border-indigo-600')) {
        selectedOptions[btn.dataset.option] = btn.dataset.value
      }
    })

    // Find the variant that matches all selected options
    const match = this.variantsValue.find(v => {
      return Object.entries(selectedOptions).every(([name, value]) => {
        return v.options[name] === value
      })
    })

    if (match) {
      this.priceTarget.textContent = `Rp ${new Intl.NumberFormat('id-ID').format(match.price)}`
      this.variantIdTarget.value = match.id
      this.buttonTarget.disabled = !match.active || match.stock <= 0
      this.buttonTarget.textContent = match.stock > 0 ? "Add to Cart" : "Out of Stock"
    }
  }
}
