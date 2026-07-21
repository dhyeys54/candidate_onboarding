require "test_helper"

class Admin::EmploymentTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    @headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }
  end

  teardown do
    ENV.delete("ADMIN_USERNAME")
    ENV.delete("ADMIN_PASSWORD")
  end

  test "index requires HTTP basic auth" do
    get admin_employment_types_path

    assert_response :unauthorized
  end

  test "create adds a new employment type with relevance flags" do
    assert_difference "Onboarding::EmploymentType.count", 1 do
      post admin_employment_types_path, headers: @headers,
        params: { onboarding_employment_type: { name: "Internship", salary_relevant: "1" } }
    end

    assert_predicate Onboarding::EmploymentType.find_by(name: "Internship"), :salary_relevant?
  end

  test "update toggles active" do
    employment_type = onboarding_employment_types(:freelance)

    patch admin_employment_type_path(employment_type), headers: @headers,
      params: { onboarding_employment_type: { active: "0" } }

    assert_not employment_type.reload.active?
  end
end
