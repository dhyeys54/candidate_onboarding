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
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "availability")

    assert_equal Onboarding::FormPages::AvailabilityPage, form.page
    assert_equal Onboarding::FormPages::SkillsPage, form.previous_page
    assert_equal Onboarding::FormPages::AdditionalInformationPage, form.next_page
  end

  test "education is the fourth page, right after compensation" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "education")

    assert_equal Onboarding::FormPages::EducationPage, form.page
    assert_equal 3, Onboarding::Form::PAGES.index(Onboarding::FormPages::EducationPage)
    assert_equal Onboarding::FormPages::CompensationPage, form.previous_page
    assert_equal Onboarding::FormPages::WorkExperiencePage, form.next_page
  end

  test "work experience is the fifth page, right after education" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "work_experience")

    assert_equal Onboarding::FormPages::WorkExperiencePage, form.page
    assert_equal 4, Onboarding::Form::PAGES.index(Onboarding::FormPages::WorkExperiencePage)
    assert_equal Onboarding::FormPages::EducationPage, form.previous_page
    assert_equal Onboarding::FormPages::SkillsPage, form.next_page
  end

  test "skills is the sixth page, right after work experience" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "skills")

    assert_equal Onboarding::FormPages::SkillsPage, form.page
    assert_equal 5, Onboarding::Form::PAGES.index(Onboarding::FormPages::SkillsPage)
    assert_equal Onboarding::FormPages::WorkExperiencePage, form.previous_page
    assert_equal Onboarding::FormPages::AvailabilityPage, form.next_page
  end

  test "the last page has no next page" do
    form = Onboarding::Form.new(candidate_profile: profile, page_key: "additional_information")

    assert form.last_page?
    assert_nil form.next_page
  end
end
