module Onboarding
  # Admin-managed employment type list (see Onboarding::FormPages::CompensationPage), replacing the
  # old hardcoded Onboarding::CandidateProfile::EMPLOYMENT_TYPES constant. `salary_relevant`/
  # `percentage_relevant` drive which compensation fields the Compensation page requires/shows —
  # previously CandidateProfile::SALARY_RELEVANT_EMPLOYMENT_TYPES/PERCENTAGE_RELEVANT_EMPLOYMENT_TYPES.
  class EmploymentType < ApplicationRecord
    has_many :candidate_employment_types, class_name: "Onboarding::CandidateEmploymentType", dependent: :restrict_with_error
    has_many :candidate_profiles, through: :candidate_employment_types

    validates :name, presence: true, uniqueness: true

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :name) }

    def to_s
      name
    end
  end
end
