import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.isRecording = false
    this.isSpeaking = false
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  async startRecording() {
    if (this.isRecording) return

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      alert("L'accès au microphone n'est pas supporté par ton navigateur.")
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.isRecording = true
      this.element.classList.add("is-recording")

      const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : "audio/webm"

      this.mediaRecorder = new MediaRecorder(stream, { mimeType })
      const chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data)
      }

      this.mediaRecorder.onstop = async () => {
        this.isRecording = false
        this.element.classList.remove("is-recording")
        stream.getTracks().forEach((t) => t.stop())

        if (chunks.length === 0) return

        const blob = new Blob(chunks, { type: mimeType })
        const base64 = await this.blobToBase64(blob)
        const text = await this.transcribe(base64)

        if (text && this.hasInputTarget) {
          this.inputTarget.value = text
          this.inputTarget.form.requestSubmit()
        }
      }

      this.mediaRecorder.start()
      setTimeout(() => {
        if (this.mediaRecorder?.state === "recording") {
          this.mediaRecorder.stop()
        }
      }, 30000)
    } catch (err) {
      this.isRecording = false
      this.element.classList.remove("is-recording")
      console.error("Erreur microphone:", err)
      alert("Impossible d'accéder au microphone. Vérifie les permissions.")
    }
  }

  async speak({ params: { text } }) {
    if (!text || this.isSpeaking) return

    this.isSpeaking = true

    try {
      const response = await fetch("/tts/speak", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ text, voice: "ff_siwis" })
      })

      if (!response.ok) {
        console.error("TTS failed:", response.status)
        return
      }

      const blob = await response.blob()
      const url = URL.createObjectURL(blob)
      const audio = new Audio(url)
      const cleanup = () => {
        this.isSpeaking = false
        URL.revokeObjectURL(url)
      }
      audio.addEventListener("ended", cleanup)
      audio.addEventListener("error", cleanup)
      await audio.play().catch((err) => {
        console.error("Playback failed:", err)
        cleanup()
      })
    } catch (err) {
      console.error("Erreur TTS:", err)
    }
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
          format: "webm",
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
