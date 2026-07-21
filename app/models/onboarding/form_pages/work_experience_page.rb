module Onboarding
  module FormPages
    class WorkExperiencePage < Onboarding::FormPage
      self.key = :work_experience
      self.title = "Work experience"
      self.partial = "onboarding/candidate_profiles/form_pages/work_experience"

      fields work_experiences_attributes: [
        :id, :job_title, :company_name, :start_date, :end_date, :current_job, :responsibilities, :_destroy
      ]

      def self.validate(candidate_profile)
        validate_at_least_one(candidate_profile, :work_experiences)
      end
    end
  end
end
