module Onboarding
  # Extracts text from the uploaded CV (Onboarding::CvParsing::TextExtractor), pulls structured
  # fields out of it (Onboarding::CvParsing::FieldExtractor), and pre-fills the candidate's profile
  # with them (Onboarding::CvParsing::ProfileMapper). Reports success/failure through
  # CandidateDocument#parsing_status; any failure anywhere in the pipeline (unreadable file, no
  # extractable text, a mapper error) degrades to parsing_status: :failed, which the UI turns into
  # the manual-fill fallback rather than blocking the candidate.
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

      text = CvParsing::TextExtractor.new(content_type: candidate_document.file.blob.content_type, content: content).call
      raise UnreadableFileError, "no extractable text found" if text.blank?

      extracted_fields = CvParsing::FieldExtractor.new(text).call
      CvParsing::ProfileMapper.new(candidate_document, extracted_fields).call

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
