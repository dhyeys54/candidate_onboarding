require "test_helper"

class Onboarding::CandidateDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post onboarding_candidates_path,
      params: { consent: "1", cv: Rack::Test::UploadedFile.new(file_fixture("sample_cv.pdf"), "application/pdf") }
    @profile = Onboarding::CandidateProfile.last
  end

  test "show streams the candidate's own CV" do
    get onboarding_candidate_profile_cv_path(@profile)

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "show sets the original filename on the response" do
    get onboarding_candidate_profile_cv_path(@profile)

    assert_response :success
    assert_match(/filename="sample_cv.pdf"/, response.headers["Content-Disposition"])
  end

  test "show 404s for a candidate profile that isn't the current session's" do
    other_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile

    get onboarding_candidate_profile_cv_path(other_profile)

    assert_response :not_found
  end

  test "show 404s when there is no CV attached yet" do
    @profile.candidate_documents.destroy_all

    get onboarding_candidate_profile_cv_path(@profile)

    assert_response :not_found
  end

  test "a different browser session with no candidate token cannot download the CV" do
    open_session do |guest|
      guest.get guest.onboarding_candidate_profile_cv_path(@profile)
      assert_equal 404, guest.response.status
    end
  end
end
