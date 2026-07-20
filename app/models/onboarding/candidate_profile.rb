module Onboarding
  class CandidateProfile < ApplicationRecord
    # Placeholder value lists (regions/employment_types) until the platform's real lists are known —
    # see the "candidate setup" plan for context. Swap the values here when they land; the array-column
    # + inclusion-validation shape doesn't need to change.
    REGIONS = %w[north south east west central].freeze
    EMPLOYMENT_TYPES = %w[employed self_employed freelance].freeze

    TRANSPORT_TYPES = %w[bike scooter public_transport car].freeze
    WORKING_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

    BIG_RELEVANT_JOB_FUNCTIONS = %w[general_dentist dental_hygienist specialist].freeze
    REVENUE_RELEVANT_JOB_FUNCTIONS = %w[general_dentist dental_hygienist specialist prevention_assistant].freeze
    SALARY_RELEVANT_EMPLOYMENT_TYPES = %w[employed].freeze
    PERCENTAGE_RELEVANT_EMPLOYMENT_TYPES = %w[self_employed freelance].freeze

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

    validate :regions_are_valid
    validate :employment_types_are_valid
    validate :transport_types_are_valid
    validate :working_days_are_valid

    with_options on: :submission do
      validates :phone, :city, :country, presence: true
      validates :job_function, presence: true
      validates :max_travel_time_minutes, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :search_status, presence: true
      validates :years_of_experience, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :available_from, presence: true

      validate :at_least_one_region
      validate :at_least_one_employment_type
      validate :at_least_one_working_day
      validate :at_least_one_language
      validate :desired_gross_salary_required_if_salary_relevant
      validate :desired_percentage_required_if_percentage_relevant
      validate :average_daily_revenue_required_if_revenue_relevant
      validate :big_registration_status_required_if_big_relevant
      validate :big_number_required_if_big_registered
    end

    private

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

    def at_least_one_region
      errors.add(:regions, "must have at least one selected") if regions.blank?
    end

    def at_least_one_employment_type
      errors.add(:employment_types, "must have at least one selected") if employment_types.blank?
    end

    def at_least_one_working_day
      errors.add(:working_days, "must have at least one selected") if working_days.blank?
    end

    def at_least_one_language
      errors.add(:languages, "must have at least one selected") if languages.empty?
    end

    def desired_gross_salary_required_if_salary_relevant
      return unless (employment_types & SALARY_RELEVANT_EMPLOYMENT_TYPES).any?

      errors.add(:desired_gross_salary, "can't be blank") if desired_gross_salary.blank?
    end

    def desired_percentage_required_if_percentage_relevant
      return unless (employment_types & PERCENTAGE_RELEVANT_EMPLOYMENT_TYPES).any?

      errors.add(:desired_percentage, "can't be blank") if desired_percentage.blank?
    end

    def average_daily_revenue_required_if_revenue_relevant
      return unless job_function.present? && REVENUE_RELEVANT_JOB_FUNCTIONS.include?(job_function)

      errors.add(:average_daily_revenue, "can't be blank") if average_daily_revenue.blank?
    end

    def big_registration_status_required_if_big_relevant
      return unless job_function.present? && BIG_RELEVANT_JOB_FUNCTIONS.include?(job_function)

      errors.add(:big_registration_status, "can't be blank") if big_registration_status.blank?
    end

    def big_number_required_if_big_registered
      return unless big_registration_status == "big_registered"

      errors.add(:big_number, "can't be blank") if big_number.blank?
    end
  end
end
