class CvFileValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, file)
    return unless file.attached?

    config = Rails.application.config.x.cv_upload

    unless config.allowed_content_types.include?(file.blob.content_type)
      record.errors.add(attribute, "must be a PDF or Word document (.pdf, .doc, .docx)")
    end

    if file.blob.byte_size > config.max_size
      record.errors.add(attribute, "is too large (maximum is #{config.max_size / 1.megabyte}MB)")
    end
  end
end
