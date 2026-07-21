module Admin
  # Streams a submitted candidate's CV bytes through the app (same proxy-download approach as
  # Onboarding::CandidateDocumentsController) rather than redirecting to an Active Storage blob URL.
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
      @candidate_profile = Onboarding::CandidateProfile.where(onboarding_status: :submitted).find(params[:candidate_id])
    end

    def set_candidate_document
      @candidate_document = @candidate_profile.candidate_documents.order(created_at: :desc).first
    end
  end
end
