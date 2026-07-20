module Onboarding
  class CandidateSkill < ApplicationRecord
    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"
    belongs_to :skill, class_name: "Onboarding::Skill", optional: true

    validates :skill_id, uniqueness: { scope: :candidate_profile_id }, allow_nil: true
    validate :skill_or_suggested_name_present

    private

    def skill_or_suggested_name_present
      if skill_id.blank? && suggested_name.blank?
        errors.add(:base, "must reference a skill or provide a suggested name")
      elsif skill_id.present? && suggested_name.present?
        errors.add(:base, "can't have both a skill and a suggested name")
      end
    end
  end
end
