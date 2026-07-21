require "test_helper"

class Onboarding::CandidatesControllerTest < ActionDispatch::IntegrationTest
  test "root routes to the CV upload landing page" do
    get root_path

    assert_response :success
    assert_select "h1", "Upload your CV"
  end

  test "index renders the CV upload landing page" do
    get onboarding_candidates_path

    assert_response :success
    assert_select "h1", "Upload your CV"
  end

  def uploaded_file(fixture_name, content_type:)
    Rack::Test::UploadedFile.new(file_fixture(fixture_name), content_type)
  end

  test "create with a valid CV and consent redirects to the candidate profile status page" do
    assert_enqueued_with(job: ParseCandidateCvJob) do
      post onboarding_candidates_path,
        params: { consent: "1", cv: uploaded_file("sample_cv.pdf", content_type: "application/pdf") }
    end

    assert_redirected_to onboarding_candidate_profile_path(Onboarding::CandidateProfile.last)
  end

  test "create with a valid CV and consent sets consent_given_at and a session token on the profile" do
    post onboarding_candidates_path,
      params: { consent: "1", cv: uploaded_file("sample_cv.pdf", content_type: "application/pdf") }

    profile = Onboarding::CandidateProfile.last
    assert profile.consent_given_at.present?
    assert profile.session_token.present?
    assert_equal profile.session_token, session[:candidate_token]
  end

  test "create without consent re-renders index with an error" do
    post onboarding_candidates_path, params: { cv: uploaded_file("sample_cv.pdf", content_type: "application/pdf") }

    assert_response :unprocessable_entity
    assert_select "h1", "Upload your CV"
    assert_match(/accept the consent statement/, flash[:alert])
  end

  test "create without consent does not create a guest user or profile" do
    assert_no_difference [ "Base::User.count", "Onboarding::CandidateProfile.count" ] do
      post onboarding_candidates_path, params: { cv: uploaded_file("sample_cv.pdf", content_type: "application/pdf") }
    end
  end

  test "create with a disallowed content type re-renders index with an error" do
    post onboarding_candidates_path, params: { consent: "1", cv: uploaded_file("sample_cv.txt", content_type: "text/plain") }

    assert_response :unprocessable_entity
    assert_select "h1", "Upload your CV"
    assert_match(/PDF or Word document/, flash[:alert])
  end

  test "create without a file re-renders index with an error" do
    post onboarding_candidates_path, params: { consent: "1" }

    assert_response :unprocessable_entity
    assert_match(/choose a CV file/, flash[:alert])
  end

  test "create with a disallowed content type does not create a guest user or profile" do
    assert_no_difference [ "Base::User.count", "Onboarding::CandidateProfile.count" ] do
      post onboarding_candidates_path, params: { consent: "1", cv: uploaded_file("sample_cv.txt", content_type: "text/plain") }
    end
  end

  test "create without a file does not create a guest user or profile" do
    assert_no_difference [ "Base::User.count", "Onboarding::CandidateProfile.count" ] do
      post onboarding_candidates_path, params: { consent: "1" }
    end
  end

  test "create with a non-file cv param re-renders index with an error instead of raising" do
    post onboarding_candidates_path, params: { consent: "1", cv: "not-a-file" }

    assert_response :unprocessable_entity
    assert_match(/choose a CV file/, flash[:alert])
  end
end
