module Onboarding
  class Skill < ApplicationRecord
    enum :job_function, Onboarding::JobFunctions::VALUES

    has_many :candidate_skills, class_name: "Onboarding::CandidateSkill", dependent: :destroy
    has_many :candidate_profiles, through: :candidate_skills

    validates :name, presence: true, uniqueness: { scope: :job_function }
  end
end
