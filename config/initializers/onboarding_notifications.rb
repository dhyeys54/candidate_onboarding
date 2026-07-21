# Post-submission notifications for a completed candidate onboarding (Onboarding::CompleteCandidateProfileService).
# Both are optional and fail closed when unset — no recipient/URL configured means no send is attempted.
Rails.application.config.x.onboarding = ActiveSupport::OrderedOptions.new
Rails.application.config.x.onboarding.recruitment_team_email = ENV.fetch("RECRUITMENT_TEAM_EMAIL", nil)
Rails.application.config.x.onboarding.webhook_url = ENV.fetch("CANDIDATE_ONBOARDING_WEBHOOK_URL", nil)
