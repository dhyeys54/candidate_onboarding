module Onboarding
  module FormPages
    class PersonalDetailsPage < Onboarding::FormPage
      self.key = :personal_details
      self.title = "Personal details"
      self.partial = "onboarding/candidate_profiles/form_pages/personal_details"

      fields :phone, :city, :country,
        candidate_languages_attributes: [ :id, :language_id, :proficiency, :_destroy ]
      user_fields :first_name, :last_name, :email

      # Lenient on purpose: accepts international formats (leading +, spaces, dashes, parentheses)
      # rather than pinning to one country's numbering plan.
      PHONE_FORMAT = /\A\+?[\d\s().-]{7,20}\z/

      def self.validate(candidate_profile)
        valid = true

        %i[phone city country].each do |attribute|
          next if candidate_profile.public_send(attribute).present?

          candidate_profile.errors.add(attribute, :blank)
          valid = false
        end

        if candidate_profile.phone.present? && candidate_profile.phone !~ PHONE_FORMAT
          candidate_profile.errors.add(:phone, "must be a valid phone number")
          valid = false
        end

        unless candidate_profile.any_languages_selected?
          candidate_profile.errors.add(:languages, "must have at least one selected")
          valid = false
        end

        valid
      end
    end
  end
end
