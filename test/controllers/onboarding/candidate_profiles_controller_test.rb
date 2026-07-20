require "test_helper"

class Onboarding::CandidateProfilesControllerTest < ActionDispatch::IntegrationTest
  def build_document(parsing_status:)
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("%PDF-1.4\ncontent"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document.update!(parsing_status: parsing_status)
    document
  end

  test "show renders the processing state while parsing is pending" do
    build_document(parsing_status: :pending)

    get onboarding_candidate_profile_path(onboarding_candidate_profiles(:draft_profile))

    assert_response :success
    assert_select "#cv_status", /reading your CV/
  end

  test "show renders success with a link to continue once parsing completes" do
    build_document(parsing_status: :completed)
    profile = onboarding_candidate_profiles(:draft_profile)

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /parsed successfully/
    assert_select "#cv_status a[href=?]", edit_onboarding_candidate_profile_path(profile)
  end

  test "show renders an error with a manual fallback link when parsing fails" do
    build_document(parsing_status: :failed)
    profile = onboarding_candidate_profiles(:draft_profile)

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /couldn't read your CV/
    assert_select "#cv_status a", "Fill in the form manually"
  end

  test "edit renders the placeholder profile page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    get edit_onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "h1", "Let's finish your profile"
  end
end
