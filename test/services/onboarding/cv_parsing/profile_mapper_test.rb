require "test_helper"

class Onboarding::CvParsing::ProfileMapperTest < ActiveSupport::TestCase
  def build_document(candidate_profile)
    document = candidate_profile.candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("x" * 1.kilobyte), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document
  end

  def build_guest_profile
    Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
  end

  def value(v, confidence: :high, matched_pattern: "test")
    Onboarding::CvParsing::ExtractedValue.new(value: v, confidence: confidence, matched_pattern: matched_pattern)
  end

  test "applies extracted identity and profile fields, and flips guest role to candidate" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = {
      first_name: value("Jane"),
      last_name: value("van Dijk"),
      email: value("jane@example.com"),
      city: value("Amsterdam")
    }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    user = profile.user.reload
    profile.reload
    assert_equal "Jane", user.first_name
    assert_equal "van Dijk", user.last_name
    assert_equal "jane@example.com", user.email
    assert_predicate user, :candidate?
    assert_equal "Amsterdam", profile.city
    assert_equal({ "city" => "high" }, profile.extracted_fields)
  end

  test "does not overwrite an already-set profile field" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = { job_function: value("specialist") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_equal "general_dentist", profile.job_function
    assert_not profile.extracted_fields.key?("job_function")
  end

  test "does not overwrite the identity of a non-guest user" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    original_email = profile.user.email
    extracted = { email: value("someone-else@example.com") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_equal original_email, profile.user.reload.email
  end

  test "does not flip role when no identity field is extracted" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { city: value("Amsterdam") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_predicate profile.user.reload, :guest?
  end

  test "flips role when only email (not name) is extracted" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { email: value("jane@example.com") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_predicate profile.user.reload, :candidate?
  end

  test "logs every extracted field regardless of whether it was applied" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = {
      job_function: value("specialist"),
      phone: value("06-12345678")
    }

    assert_difference "document.cv_field_extractions.count", 2 do
      Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    end

    fields = document.cv_field_extractions.pluck(:field)
    assert_includes fields, "job_function"
    assert_includes fields, "phone"
  end

  test "is idempotent across repeated calls" do
    profile = build_guest_profile
    document = build_document(profile)

    Onboarding::CvParsing::ProfileMapper.new(document, { city: value("Amsterdam") }).call
    Onboarding::CvParsing::ProfileMapper.new(document, { city: value("Rotterdam") }).call

    assert_equal "Amsterdam", profile.reload.city
  end
end
