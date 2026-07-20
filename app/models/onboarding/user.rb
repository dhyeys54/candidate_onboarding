module Onboarding
  class User < ApplicationRecord
    self.table_name = "users"

    has_one :candidate_profile, class_name: "Onboarding::CandidateProfile", dependent: :destroy

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :first_name, :last_name, presence: true
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
