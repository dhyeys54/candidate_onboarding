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

  connect() {
    this.toggleEmploymentSections()
    this.toggleBigNumberSection()
  }

  toggleEmploymentSections() {
    const checked = this.employmentCheckboxTargets.filter((box) => box.checked).map((box) => box.value)

    if (this.hasSalarySectionTarget) {
      this.salarySectionTarget.classList.toggle("hidden", !checked.includes("employed"))
    }

    if (this.hasPercentageSectionTarget) {
      const percentageBased = checked.some((type) => [ "self_employed", "freelance" ].includes(type))
      this.percentageSectionTarget.classList.toggle("hidden", !percentageBased)
    }
  }

  toggleBigNumberSection() {
    if (!this.hasBigStatusSelectTarget || !this.hasBigNumberSectionTarget) return

    this.bigNumberSectionTarget.classList.toggle("hidden", this.bigStatusSelectTarget.value !== "big_registered")
  }
}
