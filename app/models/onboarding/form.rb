module Onboarding
  # Drives the multi-page onboarding review form. Not ActiveRecord-backed: it's a thin PORO built
  # per-request from a CandidateProfile and a page key (usually the "page" URL param), and exposes
  # the ordered page list so the controller/views can navigate without persisting progress anywhere.
  class Form
    PAGES = [
      Onboarding::FormPages::PersonalDetailsPage,
      Onboarding::FormPages::JobDetailsPage,
      Onboarding::FormPages::CompensationPage,
      Onboarding::FormPages::EducationPage,
      Onboarding::FormPages::WorkExperiencePage,
      Onboarding::FormPages::SkillsPage,
      Onboarding::FormPages::AvailabilityPage,
      Onboarding::FormPages::AdditionalInformationPage
    ].freeze

    attr_reader :candidate_profile, :page

    def initialize(candidate_profile:, page_key: nil)
      @candidate_profile = candidate_profile
      @page = self.class.page_for(page_key) || PAGES.first
    end

    def self.page_for(key)
      PAGES.find { |page| page.key == key.to_s.to_sym } if key.present?
    end

    def pages
      PAGES
    end

    def previous_page
      PAGES[page_index - 1] if page_index > 0
    end

    def next_page
      PAGES[page_index + 1]
    end

    def first_page?
      page_index.zero?
    end

    def last_page?
      page_index == PAGES.length - 1
    end

    private

    def page_index
      PAGES.index(page)
    end
  end
end
