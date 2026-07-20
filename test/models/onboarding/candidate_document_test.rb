require "test_helper"

class Onboarding::CandidateDocumentTest < ActiveSupport::TestCase
  def attach_file(document, content_type: "application/pdf", byte_size: 1.kilobyte)
    document.file.attach(
      io: StringIO.new("x" * byte_size),
      filename: "cv.pdf",
      content_type: content_type
    )
  end

  test "invalid without an attached file" do
    document = Onboarding::CandidateDocument.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))

    assert_not document.valid?
    assert_includes document.errors.attribute_names, :file
  end

  test "invalid with a disallowed content type" do
    document = Onboarding::CandidateDocument.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))
    attach_file(document, content_type: "image/png")

    assert_not document.valid?
    assert_includes document.errors.attribute_names, :file
  end

  test "invalid when the file is too large" do
    document = Onboarding::CandidateDocument.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))
    attach_file(document, byte_size: Rails.application.config.x.cv_upload.max_size + 1)

    assert_not document.valid?
    assert_includes document.errors.attribute_names, :file
  end

  test "valid with an attached PDF within the size limit" do
    document = Onboarding::CandidateDocument.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))
    attach_file(document)

    assert document.valid?
  end

  test "defaults document_type to cv and parsing_status to pending" do
    document = Onboarding::CandidateDocument.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))

    assert document.cv?
    assert document.pending?
  end
end
