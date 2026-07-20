require "test_helper"

class Onboarding::CvFieldExtractionTest < ActiveSupport::TestCase
  def build_document
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("x" * 1.kilobyte), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document
  end

  test "invalid without a candidate_document or field" do
    extraction = Onboarding::CvFieldExtraction.new(confidence: :high)

    assert_not extraction.valid?
    assert_includes extraction.errors.attribute_names, :candidate_document
    assert_includes extraction.errors.attribute_names, :field
  end

  test "valid with a candidate_document, field, and confidence" do
    extraction = build_document.cv_field_extractions.build(field: "email", extracted_value: "jane@example.com", confidence: :high)

    assert extraction.valid?
  end

  test "exposes confidence as an enum" do
    extraction = build_document.cv_field_extractions.create!(field: "email", extracted_value: "jane@example.com", confidence: :high)

    assert_predicate extraction, :high?
  end

  test "destroyed when its candidate_document is destroyed" do
    document = build_document
    document.cv_field_extractions.create!(field: "email", extracted_value: "jane@example.com", confidence: :high)

    assert_difference "Onboarding::CvFieldExtraction.count", -1 do
      document.destroy
    end
  end
end
