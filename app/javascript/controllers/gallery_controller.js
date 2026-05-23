import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["main", "thumb"]

  select(event) {
    this.mainTarget.src = event.currentTarget.dataset.src
    this.thumbTargets.forEach(t => t.classList.remove('ring-2', 'ring-indigo-500'))
    event.currentTarget.classList.add('ring-2', 'ring-indigo-500')
  }
}
