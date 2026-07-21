module Onboarding
  # Admin-managed region list a candidate can pick as a job preference (see
  # Onboarding::FormPages::JobDetailsPage), replacing the old hardcoded
  # Onboarding::CandidateProfile::REGIONS constant.
  class Region < ApplicationRecord
    include Onboarding::Optionable

    has_many :candidate_regions, class_name: "Onboarding::CandidateRegion", dependent: :restrict_with_error
    has_many :candidate_profiles, through: :candidate_regions

    validates :name, presence: true, uniqueness: true

    scope :ordered, -> { order(:position, :name) }
  end
end
