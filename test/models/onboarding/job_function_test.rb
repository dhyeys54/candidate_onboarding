require "test_helper"

class Onboarding::JobFunctionTest < ActiveSupport::TestCase
  test "invalid without a key or name" do
    job_function = Onboarding::JobFunction.new

    assert_not job_function.valid?
    assert_includes job_function.errors.attribute_names, :key
    assert_includes job_function.errors.attribute_names, :name
  end

  test "invalid with a duplicate key" do
    job_function = Onboarding::JobFunction.new(key: "general_dentist", name: "General Dentist (duplicate)")

    assert_not job_function.valid?
    assert_includes job_function.errors.attribute_names, :key
  end

  test "active scope excludes inactive job functions" do
    inactive = Onboarding::JobFunction.create!(key: "retired_role", name: "Retired Role", active: false)

    assert_includes Onboarding::JobFunction.active, onboarding_job_functions(:general_dentist)
    assert_not_includes Onboarding::JobFunction.active, inactive
  end

  test "cannot be destroyed while skills reference it" do
    job_function = onboarding_job_functions(:general_dentist)

    assert_not job_function.destroy
    assert_includes job_function.errors.attribute_names, :base
  end
end
