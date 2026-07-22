module Onboarding
  class CandidateDocumentsController < ApplicationController
    include Onboarding::CandidateAuthorization

    before_action :set_candidate_profile
    before_action :authorize_candidate!
    before_action :set_candidate_document

    def show
      head :not_found and return unless @candidate_document&.file&.attached?

      send_data @candidate_document.file.download,
        filename: @candidate_document.original_filename,
        type: @candidate_document.content_type,
        disposition: "inline"
    end

    private

    def set_candidate_profile
      @candidate_profile = Onboarding::CandidateProfile.find(params[:candidate_profile_id])
    end

    def set_candidate_document
      @candidate_document = @candidate_profile.latest_candidate_document
    end
  end
end
