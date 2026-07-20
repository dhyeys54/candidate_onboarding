module Onboarding
  module FormPages
    class AvailabilityPage < Onboarding::FormPage
      self.key = :availability
      self.title = "Availability"
      self.partial = "onboarding/candidate_profiles/form_pages/availability"

      fields :available_from, :search_status, :notice_period, employment_types: []
    end
  end
end
