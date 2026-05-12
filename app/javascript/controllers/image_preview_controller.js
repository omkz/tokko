import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "grid"]

  preview() {
    const files = this.inputTarget.files
    if (!files) return

    // Clear existing previews that are not saved yet (optional)
    // For now, let's just append new ones
    
    Array.from(files).forEach(file => {
      const reader = new FileReader()
      reader.onload = (e) => {
        const previewHtml = this.createPreviewElement(e.target.result)
        this.gridTarget.insertAdjacentHTML('afterbegin', previewHtml)
      }
      reader.readAsDataURL(file)
    })
  }

  createPreviewElement(src) {
    return `
      <div class="relative group aspect-square rounded-xl overflow-hidden border border-indigo-200 bg-indigo-50 shadow-sm ring-2 ring-indigo-500 ring-offset-2 animate-in fade-in zoom-in duration-300">
        <img src="${src}" class="w-full h-full object-cover" />
        <div class="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <span class="bg-white/90 text-[10px] font-bold text-indigo-600 px-2 py-1 rounded-full shadow-sm">New</span>
        </div>
      </div>
    `
  }
}
