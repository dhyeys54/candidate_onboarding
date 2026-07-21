module Onboarding
  class CandidateRegion < ApplicationRecord
    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"
    belongs_to :region, class_name: "Onboarding::Region"

    validates :region_id, uniqueness: { scope: :candidate_profile_id }
  end
end
