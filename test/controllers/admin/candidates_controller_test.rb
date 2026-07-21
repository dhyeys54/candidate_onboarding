require "test_helper"

class Admin::CandidatesControllerTest < ActionDispatch::IntegrationTest
  def attach_cv(candidate_profile)
    document = candidate_profile.candidate_documents.build(document_type: :cv, original_filename: "cv.pdf", content_type: "application/pdf")
    document.file.attach(io: StringIO.new("%PDF-1.4\ncontent"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document
  end

  setup do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    @headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }

    @submitted_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
    @submitted_profile.user.update!(first_name: "Jamie", last_name: "Dentist", email: "jamie.dentist@example.com")
    @submitted_profile.update!(onboarding_status: :submitted)
    attach_cv(@submitted_profile)

    @draft_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
  end

  teardown do
    ENV.delete("ADMIN_USERNAME")
    ENV.delete("ADMIN_PASSWORD")
  end

  test "index requires HTTP basic auth" do
    get admin_candidates_path

    assert_response :unauthorized
  end

  test "index lists submitted candidates but not drafts" do
    get admin_candidates_path, headers: @headers

    assert_response :success
    assert_match @submitted_profile.user.email, response.body
    assert_no_match @draft_profile.user.email, response.body
  end

  test "show requires HTTP basic auth" do
    get admin_candidate_path(@submitted_profile)

    assert_response :unauthorized
  end

  test "show renders a submitted candidate's summary" do
    get admin_candidate_path(@submitted_profile), headers: @headers

    assert_response :success
    assert_match @submitted_profile.user.email, response.body
  end

  test "show 404s for a draft (not yet submitted) profile" do
    get admin_candidate_path(@draft_profile), headers: @headers

    assert_response :not_found
  end
end
