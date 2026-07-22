module Onboarding
  # Guest candidates aren't logged in — the browser's session cookie holds a token that
  # must match the profile's own session_token. Checked on every request rather than trusted once,
  # so a leaked/guessed :id in the URL alone never grants access to another candidate's data or CV.
  # Include and add `before_action :authorize_candidate!` *after* whatever before_action sets
  # @candidate_profile — order matters, since this reads that ivar.
  module CandidateAuthorization
    extend ActiveSupport::Concern

    private

    def authorize_candidate!
      token = @candidate_profile&.session_token
      head :not_found and return if token.blank?
      head :not_found and return unless ActiveSupport::SecurityUtils.secure_compare(token, session[:candidate_token].to_s)
    end
  end
end
