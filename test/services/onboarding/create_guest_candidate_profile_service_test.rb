require "test_helper"

class Onboarding::CreateGuestCandidateProfileServiceTest < ActiveSupport::TestCase
  test "creates a guest user and a candidate profile for them" do
    result = Onboarding::CreateGuestCandidateProfileService.new.call

    assert result.success?
    assert result.candidate_profile.persisted?
    assert_predicate result.candidate_profile.user, :guest?
  end

  test "each call creates a distinct guest with a unique email" do
    first = Onboarding::CreateGuestCandidateProfileService.new.call
    second = Onboarding::CreateGuestCandidateProfileService.new.call

    assert_not_equal first.candidate_profile.user.email, second.candidate_profile.user.email
  end
end
