import { Controller } from "@hotwired/stimulus"

const formatter = new Intl.NumberFormat('id-ID')

export default class extends Controller {
  static targets = ["price", "variantId", "button", "stockBadge", "quantity"]
  static values = { variants: Array }

  connect() {
    this.updateSelection()
  }

  selectOption(event) {
    const group = event.currentTarget.parentElement
    group.querySelectorAll('button').forEach(btn => {
      btn.classList.remove('border-indigo-600', 'text-indigo-600', 'ring-2', 'ring-indigo-100')
      btn.classList.add('border-gray-200', 'text-gray-600')
    })
    event.currentTarget.classList.add('border-indigo-600', 'text-indigo-600', 'ring-2', 'ring-indigo-100')
    this.updateSelection()
  }

  increment() {
    if (!this.hasQuantityTarget) return
    const max = parseInt(this.quantityTarget.dataset.max) || 99
    const val = parseInt(this.quantityTarget.value) || 1
    if (val < max) this.quantityTarget.value = val + 1
  }

  decrement() {
    if (!this.hasQuantityTarget) return
    const val = parseInt(this.quantityTarget.value) || 1
    if (val > 1) this.quantityTarget.value = val - 1
  }

  updateSelection() {
    const selectedOptions = {}
    this.element.querySelectorAll('[data-option]').forEach(btn => {
      if (btn.classList.contains('border-indigo-600')) {
        selectedOptions[btn.dataset.option] = btn.dataset.value
      }
    })

    const entries = Object.entries(selectedOptions)
    const match = entries.length === 0
      ? this.variantsValue[0]
      : this.variantsValue.find(v => entries.every(([name, value]) => v.options[name] === value))

    if (!match) return

    if (this.hasPriceTarget) {
      this.priceTarget.textContent = `Rp ${formatter.format(match.price)}`
    }
    if (this.hasVariantIdTarget) {
      this.variantIdTarget.value = match.id
    }

    const stock = match.stock ?? 0
    const inStock = match.active && stock > 0

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = !inStock
      this.buttonTarget.textContent = inStock ? "Add to Cart" : "Out of Stock"
    }
    if (this.hasQuantityTarget) {
      this.quantityTarget.dataset.max = stock
      if (parseInt(this.quantityTarget.value) > stock) {
        this.quantityTarget.value = stock > 0 ? stock : 1
      }
    }
    if (this.hasStockBadgeTarget) {
      this.#updateStockBadge(stock)
    }
  }

  #updateStockBadge(stock) {
    const states = {
      outOfStock: { text: "Out of Stock", cls: "px-2 py-1 bg-red-50 text-red-700 text-[10px] font-bold uppercase tracking-wider rounded-md border border-red-100" },
      lowStock:   { text: `Only ${stock} left`, cls: "px-2 py-1 bg-amber-50 text-amber-700 text-[10px] font-bold uppercase tracking-wider rounded-md border border-amber-100" },
      inStock:    { text: "In Stock", cls: "px-2 py-1 bg-green-50 text-green-700 text-[10px] font-bold uppercase tracking-wider rounded-md border border-green-100" }
    }
    const state = stock <= 0 ? states.outOfStock : stock <= 5 ? states.lowStock : states.inStock
    this.stockBadgeTarget.textContent = state.text
    this.stockBadgeTarget.className = state.cls
  }
}
