module Onboarding
  module FormPages
    class JobDetailsPage < Onboarding::FormPage
      self.key = :job_details
      self.title = "Job details"
      self.partial = "onboarding/candidate_profiles/form_pages/job_details"

      fields :job_function, :years_of_experience, :big_registration_status, :big_number
    end
  end
end
