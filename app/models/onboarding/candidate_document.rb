module Onboarding
  class CandidateDocument < ApplicationRecord
    enum :document_type, { cv: 0 }
    enum :parsing_status, { pending: 0, processing: 1, completed: 2, failed: 3 }, default: :pending

    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"
    has_one_attached :file
    has_many :cv_field_extractions, class_name: "Onboarding::CvFieldExtraction", dependent: :destroy

    validates :file, presence: true, cv_file: true
  end
end
