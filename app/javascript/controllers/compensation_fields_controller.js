import { Controller } from "@hotwired/stimulus"

// Employment and Compensation page: desired_gross_salary/desired_percentage only apply to certain
// employment_types picks, and big_number only applies once BIG registration is confirmed. Toggles
// those sections client-side as the candidate changes employment_types/big_registration_status.
// Sections tied to job_function (average_daily_revenue, the BIG block itself) don't need JS — the
// view only renders them at all when job_function (set on an earlier page) qualifies.
// Server-side validation (CompensationPage.validate) enforces the conditional requiredness
// regardless of what's currently shown, so hiding a field client-side never bypasses it.
export default class extends Controller {
  static targets = [ "employmentCheckbox", "salarySection", "percentageSection", "bigStatusSelect", "bigNumberSection" ]
  // Sourced from Onboarding::EmploymentType rows flagged salary_relevant/percentage_relevant (see
  // the view) so the employment-type ids driving these toggles live in exactly one place, not
  // copied here too. Checkbox values are employment_type ids (numbers), submitted as strings.
  static values = { salaryRelevantTypes: Array, percentageRelevantTypes: Array }

  connect() {
    this.toggleEmploymentSections()
    this.toggleBigNumberSection()
  }

  toggleEmploymentSections() {
    const checked = this.employmentCheckboxTargets.filter((box) => box.checked).map((box) => Number(box.value))

    if (this.hasSalarySectionTarget) {
      const salaryRelevant = checked.some((type) => this.salaryRelevantTypesValue.includes(type))
      this.salarySectionTarget.classList.toggle("hidden", !salaryRelevant)
    }

    if (this.hasPercentageSectionTarget) {
      const percentageRelevant = checked.some((type) => this.percentageRelevantTypesValue.includes(type))
      this.percentageSectionTarget.classList.toggle("hidden", !percentageRelevant)
    }
  }

  toggleBigNumberSection() {
    if (!this.hasBigStatusSelectTarget || !this.hasBigNumberSectionTarget) return

    this.bigNumberSectionTarget.classList.toggle("hidden", this.bigStatusSelectTarget.value !== "big_registered")
  }
}
