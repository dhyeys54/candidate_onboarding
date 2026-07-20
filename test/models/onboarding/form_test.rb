require "test_helper"

class Onboarding::FormTest < ActiveSupport::TestCase
  def profile
    onboarding_candidate_profiles(:draft_profile)
  end

  test "defaults to the first page when no page key is given" do
    form = Onboarding::Form.new(candidate_profile: profile)

    assert_equal Onboarding::FormPages::PersonalDetailsPage, form.page
    assert form.first_page?
    assert_nil form.previous_page
  end

  test "defaults to the first page for an unknown page key" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "not_a_real_page")

    assert_equal Onboarding::FormPages::PersonalDetailsPage, form.page
  end

  test "resolves the given page key and its neighbors" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "logistics")

    assert_equal Onboarding::FormPages::LogisticsPage, form.page
    assert_equal Onboarding::FormPages::JobDetailsPage, form.previous_page
    assert_equal Onboarding::FormPages::CompensationPage, form.next_page
  end

  test "the last page has no next page" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "skills_and_summary")

    assert form.last_page?
    assert_nil form.next_page
  end
end
