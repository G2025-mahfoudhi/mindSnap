import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "micButton", "timer"]
  static values = {
    autoSubmit: { type: Boolean, default: false },
    maxDuration: { type: Number, default: 30 }
  }

  connect() {
    this.isRecording = false
    this.isSpeaking = false
    this.isProcessing = false
    this._chunks = []
    this._stream = null
    this._mediaRecorder = null
    this._maxTimer = null
    this._timerInterval = null
    this._mimeType = null
    this._format = null
    this._audio = null
    this._speakBtn = null
    if (this.hasTimerTarget) {
      this.timerTarget.hidden = true
    }
  }

  disconnect() {
    this.cleanup()
  }

  cleanup() {
    if (this._mediaRecorder?.state === "recording") {
      this._mediaRecorder.stop()
    }
    if (this._stream) {
      this._stream.getTracks().forEach(t => t.stop())
      this._stream = null
    }
    this.clearTimers()
    this.isRecording = false
    this.isProcessing = false
    this.element.classList.remove("is-recording")
    this.resetMicButton()
  }

  clearTimers() {
    if (this._maxTimer) {
      clearTimeout(this._maxTimer)
      this._maxTimer = null
    }
    if (this._timerInterval) {
      clearInterval(this._timerInterval)
      this._timerInterval = null
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  toggle() {
    if (this.isProcessing) return
    this.isRecording ? this.stopRecording() : this.startRecording()
  }

  async startRecording() {
    if (this.isRecording || this.isProcessing) return

    if (!navigator.mediaDevices?.getUserMedia) {
      this.showError("L'enregistrement audio n'est pas supporté.")
      return
    }

    const detected = this.detectMimeType()
    if (!detected) {
      this.showError("Format audio non supporté par ton navigateur.")
      return
    }

    try {
      this._stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      })
      this.isRecording = true
      this._chunks = []
      this._mimeType = detected.mimeType
      this._format = detected.format

      if (this.hasMicButtonTarget) {
        this.micButtonTarget.classList.add("is-recording")
        this.micButtonTarget.setAttribute("aria-pressed", "true")
      }
      this.startTimer()

      this._mediaRecorder = new MediaRecorder(this._stream, {
        mimeType: this._mimeType
      })

      this._mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this._chunks.push(e.data)
      }

      this._mediaRecorder.onstop = () => {
        this.isRecording = false
        this.clearTimers()
        if (this.hasTimerTarget) this.timerTarget.hidden = true

        if (this._stream) {
          this._stream.getTracks().forEach(t => t.stop())
          this._stream = null
        }
        this.resetMicButton()
        if (this._chunks.length === 0) return

        this.processTranscription()
      }

      this._mediaRecorder.start()

      this._maxTimer = setTimeout(() => {
        if (this._mediaRecorder?.state === "recording") {
          this._mediaRecorder.stop()
        }
      }, this.maxDurationValue * 1000)

    } catch (err) {
      this.isRecording = false
      this.clearTimers()
      this.resetMicButton()
      if (this.hasTimerTarget) this.timerTarget.hidden = true
      console.error("Erreur microphone:", err)
      const msg = err.name === "NotAllowedError"
        ? "Permission micro refusée. Active-la dans les paramètres du navigateur."
        : "Micro non disponible. Vérifie qu'aucune autre app ne l'utilise."
      this.showError(msg)
    }
  }

  stopRecording() {
    if (this._mediaRecorder?.state === "recording") {
      this._mediaRecorder.stop()
    }
  }

  startTimer() {
    const startTime = Date.now()
    if (this.hasTimerTarget) {
      this.timerTarget.hidden = false
      this.timerTarget.textContent = "00:00"
    }
    this._timerInterval = setInterval(() => {
      if (!this.hasTimerTarget) return
      const elapsed = Math.floor((Date.now() - startTime) / 1000)
      const mins = String(Math.floor(elapsed / 60)).padStart(2, "0")
      const secs = String(elapsed % 60).padStart(2, "0")
      this.timerTarget.textContent = `${mins}:${secs}`
    }, 200)
  }

  async processTranscription() {
    this.isProcessing = true
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.add("is-transcribing")
    }

    const blob = new Blob(this._chunks, { type: this._mimeType })
    const base64 = await this.blobToBase64(blob)
    const text = await this.transcribe(base64)

    this.isProcessing = false
    this.resetMicButton()

    if (text && this.hasInputTarget) {
      this.inputTarget.value = text
      if (this.autoSubmitValue) {
        this.inputTarget.form.requestSubmit()
      }
    }
  }

  resetMicButton() {
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.remove("is-recording", "is-transcribing", "is-error")
      this.micButtonTarget.setAttribute("aria-pressed", "false")
    }
  }

  showError(msg) {
    console.error(msg)
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.add("is-error")
      setTimeout(() => {
        this.micButtonTarget?.classList.remove("is-error")
      }, 600)
    }
  }

  detectMimeType() {
    if (MediaRecorder.isTypeSupported("audio/webm;codecs=opus")) {
      return { mimeType: "audio/webm;codecs=opus", format: "webm" }
    }
    if (MediaRecorder.isTypeSupported("audio/mp4")) {
      return { mimeType: "audio/mp4", format: "mp4" }
    }
    if (MediaRecorder.isTypeSupported("audio/webm")) {
      return { mimeType: "audio/webm", format: "webm" }
    }
    return null
  }

  async speak({ params: { text }, currentTarget }) {
    // Re-clic sur le même bouton pendant la lecture → arrêter
    if (this.isSpeaking && this._speakBtn === currentTarget) {
      this._stopAudio()
      return
    }
    // Clic sur un autre bouton → arrêter l'audio en cours avant de démarrer
    if (this.isSpeaking) this._stopAudio()

    const cleaned = this._stripMarkdown(text || "")
    if (!cleaned) return

    this.isSpeaking = true
    this._speakBtn = currentTarget
    currentTarget?.classList.add("is-speaking")

    try {
      const response = await fetch("/tts/speak", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ text: cleaned })
      })

      if (!response.ok) {
        console.error("TTS failed:", response.status)
        this._stopAudio()
        return
      }

      const blob = await response.blob()
      const url = URL.createObjectURL(blob)
      this._audio = new Audio(url)
      const cleanup = () => {
        this.isSpeaking = false
        this._audio = null
        this._speakBtn?.classList.remove("is-speaking")
        this._speakBtn = null
        URL.revokeObjectURL(url)
      }
      this._audio.addEventListener("ended", cleanup)
      this._audio.addEventListener("error", cleanup)
      await this._audio.play().catch((err) => {
        console.error("Playback failed:", err)
        cleanup()
      })
    } catch (err) {
      console.error("Erreur TTS:", err)
      this._stopAudio()
    }
  }

  _stopAudio() {
    if (this._audio) {
      this._audio.pause()
      this._audio.src = ""
      this._audio = null
    }
    this._speakBtn?.classList.remove("is-speaking")
    this._speakBtn = null
    this.isSpeaking = false
  }

  _stripMarkdown(text) {
    return text
      .replace(/```[\s\S]*?```/g, "")         // blocs de code
      .replace(/`([^`]+)`/g, "$1")             // code inline
      .replace(/!\[.*?\]\(.*?\)/g, "")         // images
      .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1") // liens → texte
      .replace(/^#{1,6}\s+/gm, "")             // titres
      .replace(/\*\*(.+?)\*\*/gs, "$1")        // gras **
      .replace(/__(.+?)__/gs, "$1")            // gras __
      .replace(/\*(.+?)\*/gs, "$1")            // italique *
      .replace(/_([^_]+)_/gs, "$1")            // italique _
      .replace(/~~(.+?)~~/gs, "$1")            // barré
      .replace(/^[-*+]\s+/gm, "")              // listes non ordonnées
      .replace(/^\d+\.\s+/gm, "")              // listes ordonnées
      .replace(/^>\s*/gm, "")                  // citations
      .replace(/^---+$/gm, "")                 // séparateurs
      .replace(/\n{3,}/g, "\n\n")
      .trim()
  }

  clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }

  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => {
        if (reader.result && typeof reader.result === "string") {
          resolve(reader.result.split(",")[1])
        } else {
          reject(new Error("Failed to read blob"))
        }
      }
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  }

  async transcribe(base64) {
    try {
      const response = await fetch("/transcribe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({
          audio_base64: base64,
          format: this._format || "webm",
          language: "fr"
        })
      })

      if (!response.ok) {
        console.error("Transcription failed:", response.status)
        return null
      }

      const data = await response.json()
      return data.text || null
    } catch (err) {
      console.error("Erreur transcription:", err)
      return null
    }
  }
}
