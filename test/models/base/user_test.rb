require "test_helper"

class Base::UserTest < ActiveSupport::TestCase
  test "defaults to guest role" do
    user = Base::User.new(first_name: "Alex", last_name: "Doe", email: "new.user@example.com")

    assert user.guest?
  end

  test "invalid without first name, last name, or email" do
    user = Base::User.new

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :first_name
    assert_includes user.errors.attribute_names, :last_name
    assert_includes user.errors.attribute_names, :email
  end

  test "invalid with a duplicate email" do
    user = Base::User.new(first_name: "Alex", last_name: "Doe", email: users(:guest_one).email)

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :email
  end

  test "normalizes email to a stripped, downcased value" do
    user = Base::User.new(first_name: "Alex", last_name: "Doe", email: "  Mixed.Case@Example.com  ")

    assert_equal "mixed.case@example.com", user.email
  end
end
