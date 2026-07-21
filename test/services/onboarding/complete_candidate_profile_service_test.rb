require "test_helper"

class Onboarding::CompleteCandidateProfileServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @candidate_profile = onboarding_candidate_profiles(:draft_profile)
    @config = Rails.application.config.x.onboarding
    @original_email = @config.recruitment_team_email
    @original_webhook_url = @config.webhook_url
  end

  teardown do
    @config.recruitment_team_email = @original_email
    @config.webhook_url = @original_webhook_url
  end

  test "marks the profile submitted and notifies recruitment team and webhook when both are configured" do
    @config.recruitment_team_email = "recruiting@example.com"
    @config.webhook_url = "https://example.com/webhooks/onboarding"

    assert_enqueued_emails 1 do
      assert_enqueued_with(job: Onboarding::CandidateOnboardingWebhookJob, args: [ @candidate_profile.id ]) do
        Onboarding::CompleteCandidateProfileService.new(@candidate_profile).call
      end
    end

    assert_predicate @candidate_profile.reload, :submitted?
  end

  test "skips notification and webhook when neither is configured" do
    @config.recruitment_team_email = nil
    @config.webhook_url = nil

    assert_no_enqueued_jobs do
      Onboarding::CompleteCandidateProfileService.new(@candidate_profile).call
    end

    assert_predicate @candidate_profile.reload, :submitted?
  end

  test "is a no-op when the profile is already submitted" do
    @candidate_profile.update!(onboarding_status: :submitted)
    @config.recruitment_team_email = "recruiting@example.com"
    @config.webhook_url = "https://example.com/webhooks/onboarding"

    assert_no_enqueued_jobs do
      Onboarding::CompleteCandidateProfileService.new(@candidate_profile).call
    end
  end
end
