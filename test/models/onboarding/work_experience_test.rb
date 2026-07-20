require "test_helper"

class Onboarding::WorkExperienceTest < ActiveSupport::TestCase
  test "invalid without a job title or company name" do
    work_experience = Onboarding::WorkExperience.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))

    assert_not work_experience.valid?
    assert_includes work_experience.errors.attribute_names, :job_title
    assert_includes work_experience.errors.attribute_names, :company_name
  end
end
