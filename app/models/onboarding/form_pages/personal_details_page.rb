module Onboarding
  module FormPages
    class PersonalDetailsPage < Onboarding::FormPage
      self.key = :personal_details
      self.title = "Personal details"
      self.partial = "onboarding/candidate_profiles/form_pages/personal_details"

      fields :phone, :city, :country
      user_fields :first_name, :last_name, :email
    end
  end
end
