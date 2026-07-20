module Onboarding
  class UploadCvService
    Result = Struct.new(:success?, :candidate_document, :errors, keyword_init: true)

    def initialize(candidate_profile:, uploaded_file:)
      @candidate_profile = candidate_profile
      @uploaded_file = uploaded_file
    end

    def call
      return failure([ "Please choose a CV file to upload." ]) if uploaded_file.blank?

      config = Rails.application.config.x.cv_upload
      unless config.allowed_content_types.include?(uploaded_file.content_type)
        return failure([ "CV must be a PDF or Word document (.pdf, .doc, .docx)." ])
      end
      if uploaded_file.size > config.max_size
        return failure([ "CV is too large (maximum is #{config.max_size / 1.megabyte}MB)." ])
      end

      candidate_document = candidate_profile.candidate_documents.build(
        document_type: :cv,
        original_filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type,
        file_size: uploaded_file.size
      )
      candidate_document.file.attach(uploaded_file)

      if candidate_document.save
        ParseCandidateCvJob.perform_later(candidate_document.id)
        Result.new(success?: true, candidate_document: candidate_document, errors: [])
      else
        candidate_document.file.purge if candidate_document.file.attached?
        failure(candidate_document.errors.full_messages)
      end
    end

    private

    attr_reader :candidate_profile, :uploaded_file

    def failure(errors)
      Result.new(success?: false, candidate_document: nil, errors: errors)
    end
  end
end
