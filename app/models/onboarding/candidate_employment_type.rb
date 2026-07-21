module Onboarding
  class CandidateEmploymentType < ApplicationRecord
    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"
    belongs_to :employment_type, class_name: "Onboarding::EmploymentType"

    validates :employment_type_id, uniqueness: { scope: :candidate_profile_id }
  end
end
