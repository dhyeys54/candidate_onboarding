module Onboarding
  class CandidatesController < ApplicationController
    def index
      @max_size_mb = max_size_mb
    end

    def create
      return render_upload_error("Please accept the consent statement to continue.") unless params[:consent] == "1"

      validation_errors = Onboarding::UploadCvService.validate(params[:cv])
      return render_upload_error(validation_errors.to_sentence) if validation_errors.any?

      profile_result = Onboarding::CreateGuestCandidateProfileService.new.call

      unless profile_result.success?
        return render_upload_error("Something went wrong, please try again.")
      end

      candidate_profile = profile_result.candidate_profile
      candidate_profile.update!(consent_given_at: Time.current)

      upload_result = Onboarding::UploadCvService.new(
        candidate_profile: candidate_profile,
        uploaded_file: params[:cv]
      ).call

      if upload_result.success?
        session[:candidate_token] = candidate_profile.session_token
        redirect_to onboarding_candidate_profile_path(candidate_profile)
      else
        render_upload_error(upload_result.errors.to_sentence)
      end
    end

    private

    def render_upload_error(message)
      @max_size_mb = max_size_mb
      flash.now[:alert] = message
      render :index, status: :unprocessable_entity
    end

    def max_size_mb
      Rails.application.config.x.cv_upload.max_size / 1.megabyte
    end
  end
end
