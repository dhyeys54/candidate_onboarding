module Onboarding
  module FormPages
    class SkillsPage < Onboarding::FormPage
      self.key = :skills
      self.title = "Skills"
      self.partial = "onboarding/candidate_profiles/form_pages/skills"

      fields candidate_skills_attributes: [ :id, :skill_id, :suggested_name, :_destroy ]
    end
  end
end
