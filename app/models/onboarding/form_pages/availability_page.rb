module Onboarding
  module FormPages
    class AvailabilityPage < Onboarding::FormPage
      self.key = :availability
      self.title = "Availability"
      self.partial = "onboarding/candidate_profiles/form_pages/availability"

      fields :available_from, :notice_period, working_days: []

      def self.validate(candidate_profile)
        valid = true

        if candidate_profile.available_from.blank?
          candidate_profile.errors.add(:available_from, :blank)
          valid = false
        end

        if candidate_profile.working_days.blank?
          candidate_profile.errors.add(:working_days, "must have at least one selected")
          valid = false
        end

        valid
      end
    end
  end
end
