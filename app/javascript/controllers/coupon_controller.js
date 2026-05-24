import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message", "discountRow", "discountAmount", "total", "couponCode"]
  static values = { validateUrl: String }

  async apply() {
    const code = this.inputTarget.value.trim()
    if (!code) return

    const response = await fetch(this.validateUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ code })
    })

    const data = await response.json()

    if (data.valid) {
      this.messageTarget.textContent = `✓ ${data.code} applied`
      this.messageTarget.className = "text-xs font-semibold text-emerald-600 mt-2"
      this.discountRowTarget.style.display = "flex"
      this.discountAmountTarget.textContent = `- Rp ${this.formatNumber(data.discount_amount)}`
      this.totalTarget.textContent = `Rp ${this.formatNumber(data.total)}`
      this.couponCodeTarget.value = data.code
    } else {
      this.messageTarget.textContent = data.message
      this.messageTarget.className = "text-xs font-semibold text-red-500 mt-2"
      this.discountRowTarget.style.display = "none"
      this.couponCodeTarget.value = ""
    }
  }

  formatNumber(n) {
    return Math.round(n).toLocaleString("id-ID")
  }
}
