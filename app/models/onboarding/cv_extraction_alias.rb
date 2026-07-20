module Onboarding
  # Lookup dictionary the rule-based FieldExtractor consults for ambiguous fields (job_function,
  # city, country) instead of hardcoded Ruby keyword lists. Kept in the DB so future passes can grow
  # it from candidate corrections (once the review form supports editing extracted fields) without
  # touching the extractor code — see Onboarding::CvFieldExtraction for the log this would learn from.
  class CvExtractionAlias < ApplicationRecord
    enum :match_type, { keyword: 0, exact: 1 }, default: :keyword

    validates :field, :pattern, :value, presence: true
    validates :pattern, uniqueness: { scope: %i[field match_type] }

    scope :for_field, ->(field) { where(field: field) }
  end
end
