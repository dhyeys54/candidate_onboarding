require "test_helper"

class Admin::SkillsControllerTest < ActionDispatch::IntegrationTest
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
    get admin_skills_path

    assert_response :unauthorized
  end

  test "new renders the job function picker" do
    get new_admin_skill_path, headers: @headers

    assert_response :success
    assert_match "General Dentist", response.body
  end

  test "create adds a new skill scoped to a job function" do
    job_function = onboarding_job_functions(:dental_hygienist)

    assert_difference "Onboarding::Skill.count", 1 do
      post admin_skills_path, headers: @headers,
        params: { onboarding_skill: { name: "Ultrasonic scaling", job_function_id: job_function.id } }
    end

    assert_equal job_function, Onboarding::Skill.find_by(name: "Ultrasonic scaling").job_function
  end

  test "create re-renders with errors on a duplicate name for the same job function" do
    skill = onboarding_skills(:endodontics)

    assert_no_difference "Onboarding::Skill.count" do
      post admin_skills_path, headers: @headers,
        params: { onboarding_skill: { name: skill.name, job_function_id: skill.job_function_id } }
    end

    assert_response :unprocessable_entity
  end
end
