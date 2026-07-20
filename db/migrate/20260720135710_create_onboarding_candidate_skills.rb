class CreateOnboardingCandidateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_skills do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.references :skill, foreign_key: { to_table: :onboarding_skills }
      t.string :suggested_name

      t.timestamps
    end

    add_index :onboarding_candidate_skills, [ :candidate_profile_id, :skill_id ], unique: true, name: "index_onboarding_candidate_skills_on_profile_and_skill"
  end
end
