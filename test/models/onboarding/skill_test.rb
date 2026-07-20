require "test_helper"

class Onboarding::SkillTest < ActiveSupport::TestCase
  test "invalid without a name" do
    skill = Onboarding::Skill.new(job_function: :general_dentist)

    assert_not skill.valid?
    assert_includes skill.errors.attribute_names, :name
  end

  test "invalid with a duplicate name for the same job function" do
    skill = Onboarding::Skill.new(name: "Endodontics", job_function: :general_dentist)

    assert_not skill.valid?
    assert_includes skill.errors.attribute_names, :name
  end

  test "valid with a duplicate name for a different job function" do
    skill = Onboarding::Skill.new(name: "Prevention", job_function: :front_office_receptionist)

    assert skill.valid?
  end

  test "exposes job_function as an enum" do
    assert onboarding_skills(:endodontics).general_dentist?
  end
end
