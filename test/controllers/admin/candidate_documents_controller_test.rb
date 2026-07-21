require "test_helper"

class Admin::CandidateDocumentsControllerTest < ActionDispatch::IntegrationTest
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

    @profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
    @profile.update!(onboarding_status: :submitted)
    attach_cv(@profile)
  end

  teardown do
    ENV.delete("ADMIN_USERNAME")
    ENV.delete("ADMIN_PASSWORD")
  end

  test "show requires HTTP basic auth" do
    get admin_candidate_cv_path(@profile)

    assert_response :unauthorized
  end

  test "show streams a submitted candidate's CV" do
    get admin_candidate_cv_path(@profile), headers: @headers

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "show 404s for a draft (not yet submitted) profile's CV" do
    draft = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
    attach_cv(draft)

    get admin_candidate_cv_path(draft), headers: @headers

    assert_response :not_found
  end
end
