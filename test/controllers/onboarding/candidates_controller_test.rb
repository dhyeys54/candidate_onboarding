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
end
