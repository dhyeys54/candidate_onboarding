class CreateOnboardingCandidateEmploymentTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_employment_types do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.references :employment_type, null: false, foreign_key: { to_table: :onboarding_employment_types }

      t.timestamps
    end

    add_index :onboarding_candidate_employment_types, [ :candidate_profile_id, :employment_type_id ], unique: true, name: "index_onboarding_candidate_employment_types_on_profile_and_type"
  end
end
