module Onboarding
  module FormPages
    class EducationPage < Onboarding::FormPage
      self.key = :education
      self.title = "Education"
      self.partial = "onboarding/candidate_profiles/form_pages/education"

      fields educations_attributes: [ :id, :study, :institution, :level, :location, :start_date, :end_date, :_destroy ]

      def self.validate(candidate_profile)
        if candidate_profile.educations.reject(&:marked_for_destruction?).empty?
          candidate_profile.errors.add(:educations, "must have at least one entry")
        end
      end
    end
  end
end
