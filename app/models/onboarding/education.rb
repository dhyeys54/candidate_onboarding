module Onboarding
  class Education < ApplicationRecord
    enum :level, { mbo: 0, hbo: 1, bachelor: 2, master: 3, doctor: 4, course: 5 }

    LEVEL_LABELS = {
      "mbo" => "MBO",
      "hbo" => "HBO",
      "bachelor" => "Bachelor",
      "master" => "Master",
      "doctor" => "Doctor",
      "course" => "Course"
    }.freeze

    belongs_to :candidate_profile, class_name: "Onboarding::CandidateProfile"

    validates :study, presence: true
  end
end
