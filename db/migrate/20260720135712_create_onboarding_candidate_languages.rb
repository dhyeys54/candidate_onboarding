class CreateOnboardingCandidateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_languages do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.references :language, null: false, foreign_key: { to_table: :onboarding_languages }
      t.integer :proficiency

      t.timestamps
    end

    add_index :onboarding_candidate_languages, [ :candidate_profile_id, :language_id ], unique: true, name: "index_onboarding_candidate_languages_on_profile_and_language"
  end
end
