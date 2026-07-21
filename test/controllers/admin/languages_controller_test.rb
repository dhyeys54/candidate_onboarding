require "test_helper"

class Admin::LanguagesControllerTest < ActionDispatch::IntegrationTest
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
    get admin_languages_path

    assert_response :unauthorized
  end

  test "create adds a new language" do
    assert_difference "Onboarding::Language.count", 1 do
      post admin_languages_path, headers: @headers, params: { onboarding_language: { name: "Ukrainian" } }
    end

    assert_redirected_to admin_languages_path
  end

  test "create re-renders with errors on a duplicate name" do
    assert_no_difference "Onboarding::Language.count" do
      post admin_languages_path, headers: @headers, params: { onboarding_language: { name: onboarding_languages(:english).name } }
    end

    assert_response :unprocessable_entity
  end
end
