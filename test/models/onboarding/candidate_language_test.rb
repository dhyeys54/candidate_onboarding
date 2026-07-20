require "test_helper"

class Onboarding::CandidateLanguageTest < ActiveSupport::TestCase
  test "invalid with a duplicate language for the same candidate profile" do
    candidate_language = Onboarding::CandidateLanguage.new(
      candidate_profile: onboarding_candidate_profiles(:draft_profile),
      language: onboarding_languages(:english)
    )

    assert_not candidate_language.valid?
    assert_includes candidate_language.errors.attribute_names, :language_id
  end
end
