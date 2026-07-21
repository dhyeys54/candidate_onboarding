module Onboarding
  # Creates the placeholder guest identity a CandidateProfile needs to exist at all. Real
  # first_name/last_name/email are filled in later (post-parse pre-fill, or the review form the
  # candidate completes) — nothing about the person is known yet at upload time.
  class CreateGuestCandidateProfileService
    Result = Struct.new(:success?, :candidate_profile, :errors, keyword_init: true)

    def call
      user = Onboarding::User.new(
        first_name: "Guest",
        last_name: "Candidate",
        email: "guest-#{SecureRandom.uuid}@guest.dentalonboarding.invalid",
        role: :guest
      )

      return Result.new(success?: false, errors: user.errors.full_messages) unless user.save

      candidate_profile = user.create_candidate_profile!(session_token: SecureRandom.hex(32))
      Result.new(success?: true, candidate_profile: candidate_profile, errors: [])
    end
  end
end
