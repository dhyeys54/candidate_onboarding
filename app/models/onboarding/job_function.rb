module Onboarding
  # Admin-managed job function list, replacing the old hardcoded Onboarding::JobFunctions constant.
  # `key` is a stable machine slug (matched by CvExtractionAlias/webhook consumers); `name` is the
  # display label shown in the form dropdown. `big_relevant`/`revenue_relevant` drive the
  # Compensation page's conditional BIG-registration/average-daily-revenue fields — see
  # Onboarding::FormPages::CompensationPage.
  class JobFunction < ApplicationRecord
    include Onboarding::Optionable

    has_many :skills, class_name: "Onboarding::Skill", dependent: :restrict_with_error
    has_many :candidate_profiles, class_name: "Onboarding::CandidateProfile", dependent: :restrict_with_error

    validates :key, presence: true, uniqueness: true
    validates :name, presence: true

    scope :ordered, -> { order(:position, :name) }
  end
end
