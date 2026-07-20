module Onboarding
  module FormPages
    class SkillsAndSummaryPage < Onboarding::FormPage
      self.key = :skills_and_summary
      self.title = "Skills, languages & summary"
      self.partial = "onboarding/candidate_profiles/form_pages/skills_and_summary"

      fields(
        :suggested_summary, :motivation_for_employer, :reason_for_change, :reason_for_looking, :internal_notes,
        candidate_skills_attributes: [ :id, :skill_id, :suggested_name, :_destroy ],
        candidate_languages_attributes: [ :id, :language_id, :proficiency, :_destroy ]
      )
    end
  end
end
