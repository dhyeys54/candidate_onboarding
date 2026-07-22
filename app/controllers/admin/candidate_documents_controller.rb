module Admin
  class CandidateDocumentsController < BaseController
    before_action :set_candidate_profile
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
      @candidate_profile = Onboarding::CandidateProfile.submitted.find(params[:candidate_id])
    end

    def set_candidate_document
      @candidate_document = @candidate_profile.latest_candidate_document
    end
  end
end
