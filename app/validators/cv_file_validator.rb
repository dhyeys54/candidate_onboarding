class CvFileValidator < ActiveModel::EachValidator
  # Shared with Onboarding::UploadCvService.validate, which needs to reject a bad upload before a
  # CandidateDocument (and so this validator) is even in the picture — keeping the content-type/size
  # policy in one place means it can't drift between the two check points.
  def self.errors_for(content_type:, byte_size:)
    config = Rails.application.config.x.cv_upload
    errors = []

    unless config.allowed_content_types.include?(content_type)
      errors << "must be a PDF or Word document (.pdf, .doc, .docx)"
    end

    if byte_size > config.max_size
      errors << "is too large (maximum is #{config.max_size / 1.megabyte}MB)"
    end

    errors
  end

  def validate_each(record, attribute, file)
    return unless file.attached?

    self.class.errors_for(content_type: file.blob.content_type, byte_size: file.blob.byte_size).each do |message|
      record.errors.add(attribute, message)
    end
  end
end
