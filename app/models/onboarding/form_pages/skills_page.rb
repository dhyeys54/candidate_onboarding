module Onboarding
  module FormPages
    class SkillsPage < Onboarding::FormPage
      self.key = :skills
      self.title = "Skills"
      self.partial = "onboarding/candidate_profiles/form_pages/skills"

      fields candidate_skills_attributes: [ :id, :skill_id, :suggested_name, :_destroy ]

      def self.validate(candidate_profile)
        validate_at_least_one(candidate_profile, :candidate_skills)
      end
    end
  end
end
