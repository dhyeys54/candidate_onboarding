require "test_helper"

class Onboarding::CvParsingServiceTest < ActiveSupport::TestCase
  def build_document(io:, filename: "cv.pdf", content_type: "application/pdf")
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: io, filename: filename, content_type: content_type)
    document.save!
    document
  end

  test "marks the document completed and pre-fills the profile from a real CV" do
    document = build_document(io: file_fixture("cvs/sample_cv.docx").open, filename: "cv.docx",
                               content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")

    Onboarding::CvParsingService.new(document).call
    document.reload
    profile = document.candidate_profile.reload

    assert_predicate document, :completed?
    assert document.parsed_at.present?
    assert_equal "Amsterdam", profile.city
    assert_equal "high", profile.extracted_fields["city"]
  end

  test "marks the document failed when the downloaded file is empty" do
    document = build_document(io: file_fixture("empty_cv.pdf").open)

    Onboarding::CvParsingService.new(document).call
    document.reload

    assert_predicate document, :failed?
    assert_nil document.parsed_at
  end

  test "marks the document failed when the PDF is malformed" do
    document = build_document(io: file_fixture("sample_cv.pdf").open)

    Onboarding::CvParsingService.new(document).call
    document.reload

    assert_predicate document, :failed?
    assert_nil document.parsed_at
  end

  test "does not overwrite a profile field the candidate already set" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(city: "Rotterdam")
    document = build_document(io: file_fixture("cvs/sample_cv.docx").open, filename: "cv.docx",
                               content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")

    Onboarding::CvParsingService.new(document).call

    assert_equal "Rotterdam", profile.reload.city
  end
end
