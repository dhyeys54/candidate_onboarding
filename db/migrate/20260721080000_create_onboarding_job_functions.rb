class CreateOnboardingJobFunctions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_job_functions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.boolean :big_relevant, null: false, default: false
      t.boolean :revenue_relevant, null: false, default: false

      t.timestamps
    end

    add_index :onboarding_job_functions, :key, unique: true
  end
end
