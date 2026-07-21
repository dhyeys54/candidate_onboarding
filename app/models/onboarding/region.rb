module Onboarding
  # Admin-managed region list a candidate can pick as a job preference (see
  # Onboarding::FormPages::JobDetailsPage), replacing the old hardcoded
  # Onboarding::CandidateProfile::REGIONS constant.
  class Region < ApplicationRecord
    has_many :candidate_regions, class_name: "Onboarding::CandidateRegion", dependent: :restrict_with_error
    has_many :candidate_profiles, through: :candidate_regions

    validates :name, presence: true, uniqueness: true

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :name) }

    def to_s
      name
    end
  end
end
