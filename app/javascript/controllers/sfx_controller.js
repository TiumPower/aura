import { Controller } from "@hotwired/stimulus"

// Plays a short success chime on connect (scan/redeem/check-in success screens).
// Best-effort: browsers that block autoplay without a gesture stay silent.
export default class extends Controller {
  connect() {
    try {
      const ac = new (window.AudioContext || window.webkitAudioContext)()
      const play = () => [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => this.tone(ac, ac.currentTime + i * 0.11, f, 0.22, 0.13))
      if (ac.state === "suspended") ac.resume().then(play).catch(() => {})
      else play()
    } catch (e) {}
  }

  tone(ac, when, freq, dur, vol) {
    const o = ac.createOscillator(), g = ac.createGain()
    o.type = "sine"; o.frequency.value = freq
    g.gain.setValueAtTime(0.0001, when)
    g.gain.linearRampToValueAtTime(vol, when + 0.02)
    g.gain.exponentialRampToValueAtTime(0.0001, when + dur)
    o.connect(g).connect(ac.destination)
    o.start(when); o.stop(when + dur + 0.03)
  }
}
