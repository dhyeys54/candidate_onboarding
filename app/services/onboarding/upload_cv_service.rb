module Onboarding
  class UploadCvService
    Result = Struct.new(:success?, :candidate_document, :errors, keyword_init: true)

    # Safe to call with arbitrary params[:cv] input, including nil, a plain string (a client can send
    # a "cv" form field that isn't a real file part), or anything else that isn't an uploaded-file
    # object — only the last case reaches the content-type/size checks, which assume a real file.
    def self.validate(uploaded_file)
      unless uploaded_file.respond_to?(:content_type) && uploaded_file.respond_to?(:size)
        return [ "Please choose a CV file to upload." ]
      end

      CvFileValidator.errors_for(content_type: uploaded_file.content_type, byte_size: uploaded_file.size)
        .map { |message| "CV #{message}." }
    end

    def initialize(candidate_profile:, uploaded_file:)
      @candidate_profile = candidate_profile
      @uploaded_file = uploaded_file
    end

    def call
      validation_errors = self.class.validate(uploaded_file)
      return failure(validation_errors) if validation_errors.any?

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
