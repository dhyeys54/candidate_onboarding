require "test_helper"

class Onboarding::CandidateSkillTest < ActiveSupport::TestCase
  test "invalid with a duplicate skill for the same candidate profile" do
    candidate_skill = Onboarding::CandidateSkill.new(
      candidate_profile: onboarding_candidate_profiles(:draft_profile),
      skill: onboarding_skills(:endodontics)
    )

    assert_not candidate_skill.valid?
    assert_includes candidate_skill.errors.attribute_names, :skill_id
  end

  test "valid with a suggested_name and no skill" do
    candidate_skill = Onboarding::CandidateSkill.new(
      candidate_profile: onboarding_candidate_profiles(:draft_profile),
      suggested_name: "Laser dentistry"
    )

    assert candidate_skill.valid?
  end

  test "invalid without either a skill or a suggested_name" do
    candidate_skill = Onboarding::CandidateSkill.new(candidate_profile: onboarding_candidate_profiles(:draft_profile))

    assert_not candidate_skill.valid?
    assert_includes candidate_skill.errors.attribute_names, :base
  end

  test "invalid with both a skill and a suggested_name" do
    candidate_skill = Onboarding::CandidateSkill.new(
      candidate_profile: onboarding_candidate_profiles(:draft_profile),
      skill: onboarding_skills(:endodontics), suggested_name: "Laser dentistry"
    )

    assert_not candidate_skill.valid?
    assert_includes candidate_skill.errors.attribute_names, :base
  end
end
