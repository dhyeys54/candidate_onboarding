module Onboarding
  class User < Base::User
    has_one :candidate_profile, class_name: "Onboarding::CandidateProfile", dependent: :destroy

    GUEST_FIRST_NAME = "Guest"
    GUEST_LAST_NAME = "Candidate"
    GUEST_EMAIL_PATTERN = /\Aguest-[0-9a-f-]{36}@guest\.dentalonboarding\.invalid\z/

    def guest_placeholder?(field)
      case field.to_sym
      when :first_name then first_name == GUEST_FIRST_NAME
      when :last_name then last_name == GUEST_LAST_NAME
      when :email then email.to_s.match?(GUEST_EMAIL_PATTERN)
      else false
      end
    end
  end
end
