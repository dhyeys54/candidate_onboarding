module Onboarding
  class CandidateNotificationMailer < ApplicationMailer
    def recruitment_team_notification(candidate_profile)
      @candidate_profile = candidate_profile

      mail(
        to: Rails.application.config.x.onboarding.recruitment_team_email,
        subject: "New candidate onboarding completed: #{candidate_profile.user.first_name} #{candidate_profile.user.last_name}"
      )
    end
  end
end
