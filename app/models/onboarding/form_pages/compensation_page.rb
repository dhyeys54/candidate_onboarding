module Onboarding
  module FormPages
    class CompensationPage < Onboarding::FormPage
      self.key = :compensation
      self.title = "Employment and Compensation"
      self.partial = "onboarding/candidate_profiles/form_pages/compensation"

      fields :desired_gross_salary, :desired_percentage, :average_daily_revenue,
             :big_registration_status, :big_number, :years_of_experience,
             employment_type_ids: []

      def self.validate(candidate_profile)
        unless candidate_profile.any_employment_types_selected?
          candidate_profile.errors.add(:employment_types, "must have at least one selected")
        end

        if candidate_profile.years_of_experience.blank?
          candidate_profile.errors.add(:years_of_experience, :blank)
        else
          validate_numeric(candidate_profile, :years_of_experience, min: 0)
        end

        selected_employment_types = candidate_profile.selected_employment_types

        if selected_employment_types.any?(&:salary_relevant?)
          if candidate_profile.desired_gross_salary.blank?
            candidate_profile.errors.add(:desired_gross_salary, :blank)
          else
            validate_numeric(candidate_profile, :desired_gross_salary, min: 0)
          end
        end

        if selected_employment_types.any?(&:percentage_relevant?)
          if candidate_profile.desired_percentage.blank?
            candidate_profile.errors.add(:desired_percentage, :blank)
          else
            validate_numeric(candidate_profile, :desired_percentage, min: 0, max: 100)
          end
        end

        job_function = candidate_profile.job_function

        if job_function&.revenue_relevant?
          if candidate_profile.average_daily_revenue.blank?
            candidate_profile.errors.add(:average_daily_revenue, :blank)
          else
            validate_numeric(candidate_profile, :average_daily_revenue, min: 0)
          end
        end

        if job_function&.big_relevant? && candidate_profile.big_registration_status.blank?
          candidate_profile.errors.add(:big_registration_status, :blank)
        end

        if candidate_profile.big_registration_status == "big_registered" && candidate_profile.big_number.blank?
          candidate_profile.errors.add(:big_number, :blank)
        end
      end
    end
  end
end
