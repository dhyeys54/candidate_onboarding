require "test_helper"

class Onboarding::EducationTest < ActiveSupport::TestCase
  test "invalid without a study" do
    education = Onboarding::Education.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))

    assert_not education.valid?
    assert_includes education.errors.attribute_names, :study
  end

  test "invalid without a candidate_profile" do
    education = Onboarding::Education.new(study: "Dentistry")

    assert_not education.valid?
    assert_includes education.errors.attribute_names, :candidate_profile
  end

  test "exposes level as an enum" do
    assert onboarding_educations(:education_one).master?
  end
end
