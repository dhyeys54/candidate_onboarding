class CreateOnboardingSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_skills do |t|
      t.string :name, null: false
      t.integer :job_function
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :onboarding_skills, [ :name, :job_function ], unique: true, name: "index_onboarding_skills_on_name_and_job_function"
  end
end
