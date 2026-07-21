import { Controller } from "@hotwired/stimulus"

// Work experience row: hides the end_date field while "I currently work here" is checked, since a
// current position has no end date.
export default class extends Controller {
  static targets = [ "currentJobCheckbox", "endDateSection" ]

  connect() {
    this.toggleEndDate()
  }

  toggleEndDate() {
    this.endDateSectionTarget.classList.toggle("hidden", this.currentJobCheckboxTarget.checked)
  }
}
