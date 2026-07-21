require "test_helper"

class Admin::JobFunctionsControllerTest < ActionDispatch::IntegrationTest
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
    get admin_job_functions_path

    assert_response :unauthorized
  end

  test "index lists job functions" do
    get admin_job_functions_path, headers: @headers

    assert_response :success
    assert_match "General Dentist", response.body
  end

  test "create adds a new job function" do
    assert_difference "Onboarding::JobFunction.count", 1 do
      post admin_job_functions_path, headers: @headers,
        params: { onboarding_job_function: { key: "orthodontist", name: "Orthodontist", active: "1" } }
    end

    assert_redirected_to admin_job_functions_path
  end

  test "create re-renders with errors when name is missing" do
    assert_no_difference "Onboarding::JobFunction.count" do
      post admin_job_functions_path, headers: @headers,
        params: { onboarding_job_function: { key: "no_name", name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "update changes an existing job function" do
    job_function = onboarding_job_functions(:practice_manager)

    patch admin_job_function_path(job_function), headers: @headers,
      params: { onboarding_job_function: { name: "Office Manager" } }

    assert_redirected_to admin_job_functions_path
    assert_equal "Office Manager", job_function.reload.name
  end

  test "destroy removes a job function that isn't referenced" do
    job_function = onboarding_job_functions(:practice_manager)

    assert_difference "Onboarding::JobFunction.count", -1 do
      delete admin_job_function_path(job_function), headers: @headers
    end
  end

  test "destroy is blocked for a job function still referenced by a skill" do
    job_function = onboarding_job_functions(:general_dentist)

    assert_no_difference "Onboarding::JobFunction.count" do
      delete admin_job_function_path(job_function), headers: @headers
    end

    assert_redirected_to admin_job_functions_path
  end
end
