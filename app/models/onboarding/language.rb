module Onboarding
  class Language < ApplicationRecord
    has_many :candidate_languages, class_name: "Onboarding::CandidateLanguage", dependent: :destroy
    has_many :candidate_profiles, through: :candidate_languages

    validates :name, presence: true, uniqueness: true
  end
end
