module Onboarding
  class User < Base::User
    has_one :candidate_profile, class_name: "Onboarding::CandidateProfile", dependent: :destroy
  end
end
