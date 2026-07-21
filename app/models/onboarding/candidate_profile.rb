module Onboarding
  class CandidateProfile < ApplicationRecord
    # Placeholder value lists (regions/employment_types) until the platform's real lists are known —
    # see the "candidate setup" plan for context. Swap the values here when they land; the array-column
    # + inclusion-validation shape doesn't need to change.
    REGIONS = %w[north south east west central].freeze
    EMPLOYMENT_TYPES = %w[employed self_employed freelance percentage_based].freeze
    SALARY_RELEVANT_EMPLOYMENT_TYPES = %w[employed].freeze
    PERCENTAGE_RELEVANT_EMPLOYMENT_TYPES = %w[self_employed freelance percentage_based].freeze

    TRANSPORT_TYPES = %w[bike scooter public_transport car].freeze
    WORKING_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

    BIG_RELEVANT_JOB_FUNCTIONS = %w[general_dentist dental_hygienist specialist].freeze
    REVENUE_RELEVANT_JOB_FUNCTIONS = %w[general_dentist dental_hygienist specialist].freeze

    enum :job_function, Onboarding::JobFunctions::VALUES
    enum :search_status, { active: 0, passive: 1, inactive: 2 }
    enum :big_registration_status, { big_registered: 0, in_progress: 1, under_supervision: 2, not_applicable: 3 }
    enum :onboarding_status, { draft: 0, submitted: 1 }, default: :draft

    belongs_to :user, class_name: "Onboarding::User"

    has_many :educations, class_name: "Onboarding::Education", dependent: :destroy
    has_many :work_experiences, class_name: "Onboarding::WorkExperience", dependent: :destroy
    has_many :candidate_skills, class_name: "Onboarding::CandidateSkill", dependent: :destroy
    has_many :skills, through: :candidate_skills, class_name: "Onboarding::Skill"
    has_many :candidate_languages, class_name: "Onboarding::CandidateLanguage", dependent: :destroy
    has_many :languages, through: :candidate_languages, class_name: "Onboarding::Language"
    has_many :candidate_documents, class_name: "Onboarding::CandidateDocument", dependent: :destroy

    # update_only: true — a candidate always has exactly one user; without it, nested attributes
    # without an "id" (the form never submits one) would build a brand new blank User instead of
    # updating the existing one.
    accepts_nested_attributes_for :user, update_only: true
    accepts_nested_attributes_for :educations, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :work_experiences, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :candidate_skills, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :candidate_languages, allow_destroy: true, reject_if: :all_blank

    # Each of these array fields is rendered as a checkbox group with a permanently-present hidden
    # fallback field (so unchecking every box still submits the key) — real submissions always
    # include a blank string alongside any checked values. Strip those before validating/saving so
    # they don't get flagged as an invalid value and don't count toward "at least one selected".
    before_validation :strip_blank_array_values

    validate :regions_are_valid
    validate :employment_types_are_valid
    validate :transport_types_are_valid
    validate :working_days_are_valid

    # Runs the current Onboarding::Form page's own validation hook (see Onboarding::FormPage) when
    # validating/saving under that page's context — e.g. `.save(context: :personal_details)`. A
    # no-op for any other context (nil, ...), since page_for only resolves real page keys.
    validate :run_current_page_validation

    # Uses the has_many (not the has_many :through) so newly built, not-yet-persisted
    # candidate_languages (e.g. from this request's nested attributes) count before the record is
    # saved — `languages.empty?` would query the DB and miss them, wrongly rejecting a fresh pick.
    def any_languages_selected?
      candidate_languages.reject(&:marked_for_destruction?).any?
    end

    private

    def run_current_page_validation
      Onboarding::Form.page_for(validation_context)&.validate(self)
    end

    def strip_blank_array_values
      self.regions = regions.reject(&:blank?)
      self.employment_types = employment_types.reject(&:blank?)
      self.transport_types = transport_types.reject(&:blank?)
      self.working_days = working_days.reject(&:blank?)
    end

    def regions_are_valid
      invalid = Array(regions) - REGIONS
      errors.add(:regions, "contains invalid values: #{invalid.join(', ')}") if invalid.any?
    end

    def employment_types_are_valid
      invalid = Array(employment_types) - EMPLOYMENT_TYPES
      errors.add(:employment_types, "contains invalid values: #{invalid.join(', ')}") if invalid.any?
    end

    def transport_types_are_valid
      invalid = Array(transport_types) - TRANSPORT_TYPES
      errors.add(:transport_types, "contains invalid values: #{invalid.join(', ')}") if invalid.any?
    end

    def working_days_are_valid
      invalid = Array(working_days) - WORKING_DAYS
      errors.add(:working_days, "contains invalid values: #{invalid.join(', ')}") if invalid.any?
    end
  end
end
