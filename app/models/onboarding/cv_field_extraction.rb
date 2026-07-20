module Onboarding
  # Append-only log of what FieldExtractor found (and how confident it was) for each parsed CV.
  # Not read by anything yet — it's the audit trail a future pass can join against candidate
  # corrections on the review form to grow Onboarding::CvExtractionAlias over time.
  class CvFieldExtraction < ApplicationRecord
    enum :confidence, { low: 0, high: 1 }

    belongs_to :candidate_document, class_name: "Onboarding::CandidateDocument"

    validates :field, presence: true
    validates :confidence, presence: true
  end
end
