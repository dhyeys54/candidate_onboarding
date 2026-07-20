require "test_helper"

class Onboarding::CvParsingServiceTest < ActiveSupport::TestCase
  def build_document(io:, content_type: "application/pdf")
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: io, filename: "cv.pdf", content_type: content_type)
    document.save!
    document
  end

  test "marks the document completed when the file is readable" do
    document = build_document(io: StringIO.new("%PDF-1.4\nreal content"))

    Onboarding::CvParsingService.new(document).call
    document.reload

    assert_predicate document, :completed?
    assert document.parsed_at.present?
  end

  test "marks the document failed when the file is empty" do
    document = build_document(io: StringIO.new(""))

    Onboarding::CvParsingService.new(document).call
    document.reload

    assert_predicate document, :failed?
    assert_nil document.parsed_at
  end
end
