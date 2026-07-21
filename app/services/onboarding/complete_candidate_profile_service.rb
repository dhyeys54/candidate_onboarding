module Onboarding
  # Runs once a candidate saves the last review-form page: flips the profile to submitted and fires
  # the two post-submission side effects (recruiter email, automation webhook). The profile/CV/
  # education/work-experience/skills records themselves are already persisted by the page save that
  # precedes this call — this service only handles the "onboarding is now complete" transition.
  class CompleteCandidateProfileService
    def initialize(candidate_profile)
      @candidate_profile = candidate_profile
    end

    def call
      return if candidate_profile.submitted?

      candidate_profile.update!(onboarding_status: :submitted)
      notify_recruitment_team
      trigger_webhook
    end

    private

    attr_reader :candidate_profile

    def notify_recruitment_team
      return if Rails.application.config.x.onboarding.recruitment_team_email.blank?

      Onboarding::CandidateNotificationMailer.recruitment_team_notification(candidate_profile).deliver_later
    end

    def trigger_webhook
      return if Rails.application.config.x.onboarding.webhook_url.blank?

      Onboarding::CandidateOnboardingWebhookJob.perform_later(candidate_profile.id)
    end
  end
end
