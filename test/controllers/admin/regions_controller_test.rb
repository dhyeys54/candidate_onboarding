require "test_helper"

class Admin::RegionsControllerTest < ActionDispatch::IntegrationTest
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
    get admin_regions_path

    assert_response :unauthorized
  end

  test "create adds a new region" do
    assert_difference "Onboarding::Region.count", 1 do
      post admin_regions_path, headers: @headers, params: { onboarding_region: { name: "Northeast" } }
    end

    assert_redirected_to admin_regions_path
  end

  test "destroy is blocked for a region still referenced by a candidate" do
    region = onboarding_regions(:north)

    assert_no_difference "Onboarding::Region.count" do
      delete admin_region_path(region), headers: @headers
    end

    assert_redirected_to admin_regions_path
  end
end
