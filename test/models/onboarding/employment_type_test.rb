require "test_helper"

class Onboarding::EmploymentTypeTest < ActiveSupport::TestCase
  test "invalid without a name" do
    employment_type = Onboarding::EmploymentType.new

    assert_not employment_type.valid?
    assert_includes employment_type.errors.attribute_names, :name
  end

  test "invalid with a duplicate name" do
    employment_type = Onboarding::EmploymentType.new(name: "Employed")

    assert_not employment_type.valid?
    assert_includes employment_type.errors.attribute_names, :name
  end

  test "defaults salary_relevant and percentage_relevant to false" do
    employment_type = Onboarding::EmploymentType.create!(name: "Volunteer")

    assert_not employment_type.salary_relevant?
    assert_not employment_type.percentage_relevant?
  end
end
