module Onboarding
  class Skill < ApplicationRecord
    include Onboarding::Optionable

    belongs_to :job_function, class_name: "Onboarding::JobFunction", optional: true

    has_many :candidate_skills, class_name: "Onboarding::CandidateSkill", dependent: :destroy
    has_many :candidate_profiles, through: :candidate_skills

    validates :name, presence: true, uniqueness: { scope: :job_function_id }

    scope :ordered, -> { order(:name) }
  end
end
