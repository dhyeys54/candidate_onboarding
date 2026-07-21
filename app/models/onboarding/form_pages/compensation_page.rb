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
        if candidate_profile.employment_types.blank?
          candidate_profile.errors.add(:employment_types, "must have at least one selected")
        end

        if candidate_profile.years_of_experience.blank?
          candidate_profile.errors.add(:years_of_experience, :blank)
        elsif candidate_profile.years_of_experience.negative?
          candidate_profile.errors.add(:years_of_experience, "must be greater than or equal to 0")
        end

        if (candidate_profile.employment_types & Onboarding::CandidateProfile::SALARY_RELEVANT_EMPLOYMENT_TYPES).any? &&
           candidate_profile.desired_gross_salary.blank?
          candidate_profile.errors.add(:desired_gross_salary, :blank)
        end

        if (candidate_profile.employment_types & Onboarding::CandidateProfile::PERCENTAGE_RELEVANT_EMPLOYMENT_TYPES).any? &&
           candidate_profile.desired_percentage.blank?
          candidate_profile.errors.add(:desired_percentage, :blank)
        end

        if candidate_profile.job_function.present? &&
           Onboarding::CandidateProfile::REVENUE_RELEVANT_JOB_FUNCTIONS.include?(candidate_profile.job_function) &&
           candidate_profile.average_daily_revenue.blank?
          candidate_profile.errors.add(:average_daily_revenue, :blank)
        end

        if candidate_profile.job_function.present? &&
           Onboarding::CandidateProfile::BIG_RELEVANT_JOB_FUNCTIONS.include?(candidate_profile.job_function) &&
           candidate_profile.big_registration_status.blank?
          candidate_profile.errors.add(:big_registration_status, :blank)
        end

        if candidate_profile.big_registration_status == "big_registered" && candidate_profile.big_number.blank?
          candidate_profile.errors.add(:big_number, :blank)
        end
      end
    end
  end
end
