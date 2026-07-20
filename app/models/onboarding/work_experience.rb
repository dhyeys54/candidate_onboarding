module Onboarding
  class WorkExperience < ApplicationRecord
    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"

    validates :job_title, :company_name, presence: true
  end
end
