module Onboarding
  module FormPages
    class LogisticsPage < Onboarding::FormPage
      self.key = :logistics
      self.title = "Logistics"
      self.partial = "onboarding/candidate_profiles/form_pages/logistics"

      fields :max_travel_time_minutes, regions: [], transport_types: [], working_days: []
    end
  end
end
