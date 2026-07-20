# Bounds for candidate CV uploads (Onboarding::CandidateDocument). ENV-configurable so ops can
# adjust without a code change; defaults match the copy shown on the upload page.
Rails.application.config.x.cv_upload = ActiveSupport::OrderedOptions.new
Rails.application.config.x.cv_upload.max_size = ENV.fetch("CV_MAX_SIZE_MB", "25").to_i.megabytes
Rails.application.config.x.cv_upload.allowed_content_types = %w[
  application/pdf
  application/msword
  application/vnd.openxmlformats-officedocument.wordprocessingml.document
]
