module Onboarding
  module FormPages
    class JobDetailsPage < Onboarding::FormPage
      self.key = :job_details
      self.title = "Job preferences"
      self.partial = "onboarding/candidate_profiles/form_pages/job_details"

      fields :job_function_id, :search_status, :reason_for_looking, :max_travel_time_minutes,
             region_ids: [], transport_types: []

      def self.validate(candidate_profile)
        candidate_profile.errors.add(:job_function_id, :blank) if candidate_profile.job_function_id.blank?
        candidate_profile.errors.add(:regions, "must have at least one selected") unless candidate_profile.any_regions_selected?

        if candidate_profile.max_travel_time_minutes.blank?
          candidate_profile.errors.add(:max_travel_time_minutes, :blank)
        else
          validate_numeric(candidate_profile, :max_travel_time_minutes, min: 0)
        end

        candidate_profile.errors.add(:search_status, :blank) if candidate_profile.search_status.blank?
      end
    end
  end
end
