module Onboarding
  module FormPages
    class CompensationPage < Onboarding::FormPage
      self.key = :compensation
      self.title = "Employment and Compensation"
      self.partial = "onboarding/candidate_profiles/form_pages/compensation"

      fields :desired_gross_salary, :desired_percentage, :average_daily_revenue,
             :big_registration_status, :big_number, :years_of_experience,
             employment_types: []

      def self.validate(candidate_profile)
        valid = true

        if candidate_profile.employment_types.blank?
          candidate_profile.errors.add(:employment_types, "must have at least one selected")
          valid = false
        end

        if candidate_profile.years_of_experience.blank?
          candidate_profile.errors.add(:years_of_experience, :blank)
          valid = false
        elsif candidate_profile.years_of_experience.negative?
          candidate_profile.errors.add(:years_of_experience, "must be greater than or equal to 0")
          valid = false
        end

        if candidate_profile.employment_types.include?("employed") && candidate_profile.desired_gross_salary.blank?
          candidate_profile.errors.add(:desired_gross_salary, :blank)
          valid = false
        end

        if (candidate_profile.employment_types & %w[self_employed freelance]).any? &&
           candidate_profile.desired_percentage.blank?
          candidate_profile.errors.add(:desired_percentage, :blank)
          valid = false
        end

        if candidate_profile.job_function.present? &&
           Onboarding::CandidateProfile::REVENUE_RELEVANT_JOB_FUNCTIONS.include?(candidate_profile.job_function) &&
           candidate_profile.average_daily_revenue.blank?
          candidate_profile.errors.add(:average_daily_revenue, :blank)
          valid = false
        end

        if candidate_profile.job_function.present? &&
           Onboarding::CandidateProfile::BIG_RELEVANT_JOB_FUNCTIONS.include?(candidate_profile.job_function) &&
           candidate_profile.big_registration_status.blank?
          candidate_profile.errors.add(:big_registration_status, :blank)
          valid = false
        end

        if candidate_profile.big_registration_status == "big_registered" && candidate_profile.big_number.blank?
          candidate_profile.errors.add(:big_number, :blank)
          valid = false
        end

        valid
      end
    end
  end
end
