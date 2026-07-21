require "test_helper"

class Onboarding::CandidateNotificationMailerTest < ActionMailer::TestCase
  setup do
    @config = Rails.application.config.x.onboarding
    @original_email = @config.recruitment_team_email
    @config.recruitment_team_email = "recruiting@example.com"
  end

  teardown do
    @config.recruitment_team_email = @original_email
  end

  test "recruitment_team_notification addresses and describes the candidate" do
    candidate_profile = onboarding_candidate_profiles(:draft_profile)

    mail = Onboarding::CandidateNotificationMailer.recruitment_team_notification(candidate_profile)

    assert_equal [ "recruiting@example.com" ], mail.to
    assert_match candidate_profile.user.first_name, mail.subject
    assert_match candidate_profile.user.email, mail.text_part.body.to_s
    assert_match candidate_profile.user.email, mail.html_part.body.to_s
  end
end
