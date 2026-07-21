module Onboarding
  module FormPages
    class AvailabilityPage < Onboarding::FormPage
      self.key = :availability
      self.title = "Availability"
      self.partial = "onboarding/candidate_profiles/form_pages/availability"

      fields :available_from, :notice_period, working_days: []

      def self.validate(candidate_profile)
        if candidate_profile.available_from.blank?
          if candidate_profile.available_from_before_type_cast.present?
            candidate_profile.errors.add(:available_from, "is not a valid date")
          else
            candidate_profile.errors.add(:available_from, :blank)
          end
        end

        if candidate_profile.working_days.blank?
          candidate_profile.errors.add(:working_days, "must have at least one selected")
        end
      end
    end
  end
end
