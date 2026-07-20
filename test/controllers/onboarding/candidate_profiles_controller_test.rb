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

  test "edit renders the first form page by default" do
    profile = onboarding_candidate_profiles(:draft_profile)

    get edit_onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "h1", "Let's finish your profile"
    assert_select "input[name='candidate_profile[phone]']"
  end

  test "edit renders every form page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    Onboarding::Form::PAGES.each do |page|
      get edit_onboarding_candidate_profile_path(profile, page: page.key)

      assert_response :success, "expected #{page.key} to render"
    end
  end

  test "update saves the current page's fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details", user: { first_name: "Jamie" }, candidate_profile: { phone: "0612345678", city: "Amsterdam" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    profile.reload
    assert_equal "Jamie", profile.user.first_name
    assert_equal "0612345678", profile.phone
  end

  test "update with commit=Back goes to the previous page without losing the current page's edits" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "job_details", commit: "Back", candidate_profile: { years_of_experience: 5 } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "personal_details")
    assert_equal 5, profile.reload.years_of_experience
  end

  test "update on the last page has no next page to advance to" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "skills_and_summary", candidate_profile: { suggested_summary: "Great candidate" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "skills_and_summary")
  end
end
