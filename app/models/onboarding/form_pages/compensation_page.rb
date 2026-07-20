module Onboarding
  module FormPages
    class CompensationPage < Onboarding::FormPage
      self.key = :compensation
      self.title = "Compensation"
      self.partial = "onboarding/candidate_profiles/form_pages/compensation"

      fields :desired_gross_salary, :desired_percentage, :average_daily_revenue
    end
  end
end
