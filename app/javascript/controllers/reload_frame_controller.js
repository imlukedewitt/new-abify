import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 3000 },
    active: { type: Boolean, default: true }
  }

  connect() {
    if (this.activeValue) this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    if (!this.element.src) this.element.src = window.location.href
    this.timer = setInterval(() => this.element.reload(), this.intervalValue)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
  }
}
