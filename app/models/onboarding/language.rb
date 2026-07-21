module Onboarding
  class Language < ApplicationRecord
    include Onboarding::Optionable

    has_many :candidate_languages, class_name: "Onboarding::CandidateLanguage", dependent: :destroy
    has_many :candidate_profiles, through: :candidate_languages

    validates :name, presence: true, uniqueness: true

    scope :ordered, -> { order(:name) }
  end
end
