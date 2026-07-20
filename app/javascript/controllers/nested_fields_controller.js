import { Controller } from "@hotwired/stimulus"

// Generic add/remove repeater for Rails nested-attributes forms (educations, work_experiences,
// candidate_skills, candidate_languages). The template holds one row's markup with NEW_RECORD as
// an index placeholder; adding a row swaps that placeholder for a timestamp so Rails treats it as
// a new nested record. Removing an existing (persisted) row sets its _destroy field instead of
// pulling it from the DOM, so accepts_nested_attributes_for(allow_destroy: true) picks it up.
export default class extends Controller {
  static targets = [ "list", "template" ]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now())
    this.listTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()

    const row = event.target.closest("[data-nested-fields-target='row']")
    const destroyField = row.querySelector("input[name*='_destroy']")

    if (destroyField) {
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
  }
}
