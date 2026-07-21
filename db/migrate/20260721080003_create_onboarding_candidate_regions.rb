class CreateOnboardingCandidateRegions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_regions do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.references :region, null: false, foreign_key: { to_table: :onboarding_regions }

      t.timestamps
    end

    add_index :onboarding_candidate_regions, [ :candidate_profile_id, :region_id ], unique: true, name: "index_onboarding_candidate_regions_on_profile_and_region"
  end
end
