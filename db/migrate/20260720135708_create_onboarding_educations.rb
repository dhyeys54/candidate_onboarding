class CreateOnboardingEducations < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_educations do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.string :institution
      t.string :study, null: false
      t.string :location
      t.integer :level
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
