import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 3000 },
    active: { type: Boolean, default: true }
  }

  static targets = ["status"]

  connect() {
    if (this.activeValue) this.start()
  }

  disconnect() {
    this.stop()
  }

  activeValueChanged() {
    if (this.activeValue) {
      this.start()
    } else {
      this.stop()
    }
  }

  statusTargetConnected(target) {
    const active = target.dataset.active === "true"
    if (!active && this.timer) {
      this.activeValue = false
    }
  }

  start() {
    if (this.timer) return
    if (!this.element.src) this.element.src = window.location.href
    this.timer = setInterval(() => this.element.reload(), this.intervalValue)
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
