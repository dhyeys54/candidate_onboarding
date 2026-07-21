require "test_helper"

class Onboarding::CandidateOnboardingWebhookJobTest < ActiveJob::TestCase
  setup do
    @candidate_profile = onboarding_candidate_profiles(:draft_profile)
    @config = Rails.application.config.x.onboarding
    @original_webhook_url = @config.webhook_url
    @config.webhook_url = "https://example.com/webhooks/onboarding"
  end

  teardown do
    @config.webhook_url = @original_webhook_url
  end

  # minitest/mock isn't bundled (extracted from minitest 6+, and not a project dependency), so
  # Net::HTTP.post is stubbed by hand here rather than via Minitest::Mock#stub.
  def stub_http_post(response_or_proc)
    Net::HTTP.define_singleton_method(:post) do |*args|
      response_or_proc.respond_to?(:call) ? response_or_proc.call(*args) : response_or_proc
    end
    yield
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :post)
  end

  test "posts the candidate_onboarding_completed event to the configured URL" do
    success = Net::HTTPOK.new("1.1", "200", "OK")

    posted_uri = nil
    posted_body = nil
    stub_http_post(->(uri, body, _headers) { posted_uri = uri; posted_body = body; success }) do
      Onboarding::CandidateOnboardingWebhookJob.perform_now(@candidate_profile.id)
    end

    assert_equal "https://example.com/webhooks/onboarding", posted_uri.to_s
    payload = JSON.parse(posted_body)
    assert_equal "candidate_onboarding_completed", payload["event"]
    assert_equal @candidate_profile.id, payload["candidate"]["id"]
    assert_equal @candidate_profile.user.email, payload["candidate"]["email"]
  end

  test "raises when the endpoint responds with a non-success status" do
    failure = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")

    stub_http_post(failure) do
      assert_raises(Onboarding::CandidateOnboardingWebhookJob::DeliveryError) do
        Onboarding::CandidateOnboardingWebhookJob.perform_now(@candidate_profile.id)
      end
    end
  end

  test "does nothing when no webhook URL is configured" do
    @config.webhook_url = nil

    stub_http_post(->(*) { raise "should not be called" }) do
      assert_nothing_raised do
        Onboarding::CandidateOnboardingWebhookJob.perform_now(@candidate_profile.id)
      end
    end
  end
end
