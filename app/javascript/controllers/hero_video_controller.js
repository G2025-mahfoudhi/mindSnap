import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["videoA", "videoB", "wrapper"]

  connect() {
    if (this.hasReducedMotion) return

    this.active = "a"
    this.preloading = false
    this.CROSSFADE_LEAD = 0.6
    this.CROSSFADE_DURATION = 600

    this.videoA = this.videoATarget
    this.videoB = this.videoBTarget

    this.onTimeUpdateA = this.onTimeUpdateA.bind(this)
    this.onTimeUpdateB = this.onTimeUpdateB.bind(this)
    this.onEndedA = () => this.swapTo("b")
    this.onEndedB = () => this.swapTo("a")
    this.onVisibility = this.onVisibility.bind(this)

    this.videoA.addEventListener("timeupdate", this.onTimeUpdateA)
    this.videoB.addEventListener("timeupdate", this.onTimeUpdateB)
    this.videoA.addEventListener("ended", this.onEndedA)
    this.videoB.addEventListener("ended", this.onEndedB)
    document.addEventListener("visibilitychange", this.onVisibility)

    this.videoA.play().catch(() => {})
  }

  disconnect() {
    this.videoA.removeEventListener("timeupdate", this.onTimeUpdateA)
    this.videoB.removeEventListener("timeupdate", this.onTimeUpdateB)
    this.videoA.removeEventListener("ended", this.onEndedA)
    this.videoB.removeEventListener("ended", this.onEndedB)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.videoA.pause()
    this.videoB.pause()
  }

  onTimeUpdateA() {
    this.handleTimeUpdate(this.videoA, "a")
  }

  onTimeUpdateB() {
    this.handleTimeUpdate(this.videoB, "b")
  }

  handleTimeUpdate(video, side) {
    if (this.active !== side) return
    if (this.preloading) return
    if (!video.duration) return

    const remaining = video.duration - video.currentTime
    if (remaining <= this.CROSSFADE_LEAD) {
      this.prelaodOpposite(side)
    }
  }

  prelaodOpposite(currentSide) {
    this.preloading = true
    const opposite = currentSide === "a" ? this.videoB : this.videoA
    opposite.currentTime = 0
    opposite.play().catch(() => {})
  }

  swapTo(newSide) {
    const outgoing = newSide === "b" ? this.videoA : this.videoB
    const incoming = newSide === "b" ? this.videoB : this.videoA

    outgoing.style.opacity = "0"
    incoming.style.opacity = "1"
    this.active = newSide

    setTimeout(() => {
      outgoing.currentTime = 0
      outgoing.pause()
      this.preloading = false
    }, this.CROSSFADE_DURATION)
  }

  onVisibility() {
    const activeVideo = this.active === "a" ? this.videoA : this.videoB
    if (document.hidden) {
      activeVideo.pause()
    } else {
      activeVideo.play().catch(() => {})
    }
  }

  get hasReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
