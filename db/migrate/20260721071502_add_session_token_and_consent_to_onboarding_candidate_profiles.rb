class AddSessionTokenAndConsentToOnboardingCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :onboarding_candidate_profiles, :session_token, :string
    add_index :onboarding_candidate_profiles, :session_token, unique: true
    add_column :onboarding_candidate_profiles, :consent_given_at, :datetime
  end
end
