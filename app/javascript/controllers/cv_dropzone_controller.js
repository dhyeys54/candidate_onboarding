import { Controller } from "@hotwired/stimulus"

const ALLOWED_TYPES = [
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
]

// Drag-and-drop behavior for the CV upload dropzone, plus client-side size/type validation so
// candidates get instant feedback instead of waiting on a round-trip to hit the same check
// server-side (CvFileValidator / Onboarding::UploadCvService are the source of truth).
export default class extends Controller {
  static targets = [ "dropzone", "input", "filename", "error", "submit" ]
  static classes = [ "active" ]
  static values = { maxSizeMb: Number }

  browse(event) {
    if (event.target === this.inputTarget) return

    this.inputTarget.click()
  }

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add(...this.activeClasses)
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove(...this.activeClasses)
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove(...this.activeClasses)

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.handleFile(files[0])
    }
  }

  fileSelected() {
    const files = this.inputTarget.files
    if (files.length > 0) this.handleFile(files[0])
  }

  handleFile(file) {
    const error = this.validate(file)

    if (error) {
      this.filenameTarget.textContent = ""
      this.showError(error)
      this.inputTarget.value = ""
      if (this.hasSubmitTarget) this.submitTarget.disabled = true
    } else {
      this.showFilename(file)
      this.hideError()
      if (this.hasSubmitTarget) this.submitTarget.disabled = false
    }
  }

  validate(file) {
    if (!ALLOWED_TYPES.includes(file.type)) {
      return "Please choose a PDF or Word document (.pdf, .doc, .docx)."
    }

    if (this.hasMaxSizeMbValue && file.size > this.maxSizeMbValue * 1024 * 1024) {
      return `That file is too large (maximum is ${this.maxSizeMbValue}MB).`
    }

    return null
  }

  showFilename(file) {
    this.filenameTarget.textContent = file.name
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
