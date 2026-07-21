module Onboarding
  module FormPages
    class AdditionalInformationPage < Onboarding::FormPage
      self.key = :additional_information
      self.title = "Additional Information"
      self.partial = "onboarding/candidate_profiles/form_pages/additional_information"

      fields :suggested_summary, :motivation_for_employer, :reason_for_change, :internal_notes
    end
  end
end
