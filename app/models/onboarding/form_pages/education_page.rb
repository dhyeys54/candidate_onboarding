module Onboarding
  module FormPages
    class EducationPage < Onboarding::FormPage
      self.key = :education
      self.title = "Education"
      self.partial = "onboarding/candidate_profiles/form_pages/education"

      fields educations_attributes: [ :id, :study, :institution, :level, :location, :start_date, :end_date, :_destroy ]

      def self.validate(candidate_profile)
        validate_at_least_one(candidate_profile, :educations)
      end
    end
  end
end
