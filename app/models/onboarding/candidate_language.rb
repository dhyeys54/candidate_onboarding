module Onboarding
  class CandidateLanguage < ApplicationRecord
    enum :proficiency, { beginner: 0, intermediate: 1, advanced: 2, fluent: 3, native: 4 }

    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"
    belongs_to :language, class_name: "Onboarding::Language"

    validates :language_id, uniqueness: { scope: :candidate_profile_id }
  end
end
