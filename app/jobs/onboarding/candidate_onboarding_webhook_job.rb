module Onboarding
  # Fires the optional `candidate_onboarding_completed` automation webhook. Raises on a non-2xx
  # response so Sidekiq's default retry handles transient failures at the receiving end.
  class CandidateOnboardingWebhookJob < ApplicationJob
    queue_as :default

    class DeliveryError < StandardError; end

    def perform(candidate_profile_id)
      webhook_url = Rails.application.config.x.onboarding.webhook_url
      return if webhook_url.blank?

      candidate_profile = Onboarding::CandidateProfile.find(candidate_profile_id)
      uri = URI.parse(webhook_url)

      response = Net::HTTP.post(uri, payload(candidate_profile).to_json, "Content-Type" => "application/json")
      raise DeliveryError, "webhook responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    end

    private

    def payload(candidate_profile)
      user = candidate_profile.user

      {
        event: "candidate_onboarding_completed",
        occurred_at: candidate_profile.updated_at.iso8601,
        candidate: {
          id: candidate_profile.id,
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          job_function: candidate_profile.job_function
        }
      }
    end
  end
end
