module Onboarding
  # Stands in for the real CV text-extraction parser (pdf-reader/docx, not built yet). Confirms the
  # uploaded file is actually readable and reports success/failure through CandidateDocument#parsing_status
  # — real field-extraction logic can replace the body of #call later without touching callers.
  class CvParsingService
    class UnreadableFileError < StandardError; end

    def initialize(candidate_document)
      @candidate_document = candidate_document
    end

    def call
      candidate_document.update!(parsing_status: :processing)
      broadcast_status

      content = candidate_document.file.download
      raise UnreadableFileError, "downloaded file is empty" if content.blank?

      candidate_document.update!(parsing_status: :completed, parsed_at: Time.current)
    rescue StandardError => e
      Rails.logger.warn(
        "[Onboarding::CvParsingService] parsing failed for CandidateDocument##{candidate_document.id}: #{e.class}: #{e.message}"
      )
      candidate_document.update!(parsing_status: :failed)
    ensure
      broadcast_status
    end

    private

    attr_reader :candidate_document

    def broadcast_status
      candidate_profile = candidate_document.candidate_profile

      Turbo::StreamsChannel.broadcast_replace_to(
        candidate_profile,
        target: "cv_status",
        partial: "onboarding/candidate_profiles/status",
        locals: { candidate_profile: candidate_profile, candidate_document: candidate_document }
      )
    end
  end
end
