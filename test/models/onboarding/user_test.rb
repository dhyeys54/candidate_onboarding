require "test_helper"

class Onboarding::UserTest < ActiveSupport::TestCase
  test "invalid without first name, last name, or email" do
    user = Onboarding::User.new

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :first_name
    assert_includes user.errors.attribute_names, :last_name
    assert_includes user.errors.attribute_names, :email
  end

  test "invalid with a duplicate email, even one owned by a Base::User row" do
    user = Onboarding::User.new(first_name: "Alex", last_name: "Doe", email: users(:guest_one).email)

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :email
  end

  test "normalizes email to a stripped, downcased value" do
    user = Onboarding::User.new(first_name: "Alex", last_name: "Doe", email: "  Mixed.Case@Example.com  ")

    assert_equal "mixed.case@example.com", user.email
  end

  test "shares the users table with Base::User" do
    onboarding_user = Onboarding::User.find(users(:candidate_one).id)

    assert_equal users(:candidate_one).email, onboarding_user.email
  end

  test "has_one candidate_profile" do
    onboarding_user = Onboarding::User.find(users(:candidate_one).id)

    assert_equal onboarding_candidate_profiles(:draft_profile), onboarding_user.candidate_profile
  end
end
