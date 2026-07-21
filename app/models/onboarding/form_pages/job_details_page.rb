module Onboarding
  module FormPages
    class JobDetailsPage < Onboarding::FormPage
      self.key = :job_details
      self.title = "Job details"
      self.partial = "onboarding/candidate_profiles/form_pages/job_details"

      fields :job_function, :search_status, :reason_for_looking, :max_travel_time_minutes,
             regions: [], transport_types: []

      def self.validate(candidate_profile)
        valid = true

        if candidate_profile.job_function.blank?
          candidate_profile.errors.add(:job_function, :blank)
          valid = false
        end

        if candidate_profile.regions.blank?
          candidate_profile.errors.add(:regions, "must have at least one selected")
          valid = false
        end

        if candidate_profile.max_travel_time_minutes.blank?
          candidate_profile.errors.add(:max_travel_time_minutes, :blank)
          valid = false
        elsif candidate_profile.max_travel_time_minutes.negative?
          candidate_profile.errors.add(:max_travel_time_minutes, "must be greater than or equal to 0")
          valid = false
        end

        if candidate_profile.search_status.blank?
          candidate_profile.errors.add(:search_status, :blank)
          valid = false
        end

        valid
      end
    end
  end
end
