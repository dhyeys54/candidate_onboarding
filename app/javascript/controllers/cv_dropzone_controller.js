import { Controller } from "@hotwired/stimulus"

// Visual drag-and-drop behavior for the CV upload dropzone. Upload/submission
// handling is wired up separately once the backend upload endpoint exists.
export default class extends Controller {
  static targets = [ "dropzone", "input", "filename" ]
  static classes = [ "active" ]

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
      this.showFilename(files[0])
    }
  }

  fileSelected() {
    const files = this.inputTarget.files
    if (files.length > 0) this.showFilename(files[0])
  }

  showFilename(file) {
    this.filenameTarget.textContent = file.name
  }
}
