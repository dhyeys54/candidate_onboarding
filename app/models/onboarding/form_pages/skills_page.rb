module Onboarding
  module FormPages
    class SkillsPage < Onboarding::FormPage
      self.key = :skills
      self.title = "Skills"
      self.partial = "onboarding/candidate_profiles/form_pages/skills"

      fields candidate_skills_attributes: [ :id, :skill_id, :suggested_name, :_destroy ]

      def self.validate(candidate_profile)
        if candidate_profile.candidate_skills.reject(&:marked_for_destruction?).empty?
          candidate_profile.errors.add(:candidate_skills, "must have at least one entry")
        end
      end
    end
  end
end
