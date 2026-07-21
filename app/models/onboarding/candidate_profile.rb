module Onboarding
  class CandidateProfile < ApplicationRecord
    # Transport types and working days are small, stable, closed lists (a handful of transport modes;
    # the 7 days of the week) — kept as code constants rather than admin-managed lookup tables, unlike
    # job_function/regions/employment_types (see Onboarding::JobFunction/Region/EmploymentType).
    TRANSPORT_TYPES = %w[bike scooter public_transport car].freeze
    WORKING_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

    enum :search_status, { active: 0, passive: 1, inactive: 2 }
    enum :big_registration_status, { big_registered: 0, in_progress: 1, under_supervision: 2, not_applicable: 3 }
    enum :onboarding_status, { draft: 0, submitted: 1 }, default: :draft

    belongs_to :user, class_name: "Onboarding::User"
    belongs_to :job_function, class_name: "Onboarding::JobFunction", optional: true

    has_many :educations, class_name: "Onboarding::Education", dependent: :destroy
    has_many :work_experiences, class_name: "Onboarding::WorkExperience", dependent: :destroy
    has_many :candidate_skills, class_name: "Onboarding::CandidateSkill", dependent: :destroy
    has_many :skills, through: :candidate_skills, class_name: "Onboarding::Skill"
    has_many :candidate_languages, class_name: "Onboarding::CandidateLanguage", dependent: :destroy
    has_many :languages, through: :candidate_languages, class_name: "Onboarding::Language"
    has_many :candidate_documents, class_name: "Onboarding::CandidateDocument", dependent: :destroy
    has_many :candidate_regions, class_name: "Onboarding::CandidateRegion", dependent: :destroy
    has_many :regions, through: :candidate_regions, class_name: "Onboarding::Region"
    has_many :candidate_employment_types, class_name: "Onboarding::CandidateEmploymentType", dependent: :destroy
    has_many :employment_types, through: :candidate_employment_types, class_name: "Onboarding::EmploymentType"

    # update_only: true — a candidate always has exactly one user; without it, nested attributes
    # without an "id" (the form never submits one) would build a brand new blank User instead of
    # updating the existing one.
    accepts_nested_attributes_for :user, update_only: true
    accepts_nested_attributes_for :educations, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :work_experiences, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :candidate_skills, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :candidate_languages, allow_destroy: true, reject_if: :all_blank
    accepts_nested_attributes_for :candidate_regions, allow_destroy: true
    accepts_nested_attributes_for :candidate_employment_types, allow_destroy: true

    # Each of these array fields is rendered as a checkbox group with a permanently-present hidden
    # fallback field (so unchecking every box still submits the key) — real submissions always
    # include a blank string alongside any checked values. Strip those before validating/saving so
    # they don't get flagged as an invalid value and don't count toward "at least one selected".
    before_validation :strip_blank_array_values

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

    def any_regions_selected?
      candidate_regions.reject(&:marked_for_destruction?).any?
    end

    def any_employment_types_selected?
      candidate_employment_types.reject(&:marked_for_destruction?).any?
    end

    # In-memory selection (persisted rows minus any marked for destruction, plus any newly built
    # rows) rather than the `regions`/`employment_types` has_many :through readers, which query the
    # DB and so miss unsaved changes from this request — needed so a re-rendered page (after another
    # field fails validation) still shows the candidate's just-submitted checkbox state.
    def selected_region_ids
      candidate_regions.reject(&:marked_for_destruction?).map(&:region_id)
    end

    def selected_employment_type_ids
      candidate_employment_types.reject(&:marked_for_destruction?).map(&:employment_type_id)
    end

    def selected_employment_types
      Onboarding::EmploymentType.where(id: selected_employment_type_ids)
    end

    def latest_candidate_document
      candidate_documents.order(created_at: :desc).first
    end

    # Rails' has_many :through auto-generates region_ids=, but it writes to the join table
    # immediately on assignment rather than deferring to #save like accepts_nested_attributes_for
    # does — that would let a region pick persist even when the rest of the page fails validation.
    # These overrides build/mark-for-destruction CandidateRegion rows instead, same as any other
    # nested attribute, so the whole page's edits commit or roll back together (see
    # Onboarding::FormPage's validate hook for how the page-scoped save(context:) is driven).
    def region_ids=(ids)
      assign_lookup_ids(candidate_regions, :region_id, ids)
    end

    def employment_type_ids=(ids)
      assign_lookup_ids(candidate_employment_types, :employment_type_id, ids)
    end

    private

    def assign_lookup_ids(collection, foreign_key, ids)
      ids = Array(ids).reject(&:blank?).map(&:to_i)
      collection.each { |record| record.mark_for_destruction unless ids.include?(record.public_send(foreign_key)) }
      existing_ids = collection.reject(&:marked_for_destruction?).map { |record| record.public_send(foreign_key) }
      (ids - existing_ids).each { |id| collection.build(foreign_key => id) }
    end

    def run_current_page_validation
      Onboarding::Form.page_for(validation_context)&.validate(self)
    end

    def strip_blank_array_values
      self.transport_types = transport_types.reject(&:blank?)
      self.working_days = working_days.reject(&:blank?)
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
