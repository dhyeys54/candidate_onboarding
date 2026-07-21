class CreateOnboardingEmploymentTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_employment_types do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.boolean :salary_relevant, null: false, default: false
      t.boolean :percentage_relevant, null: false, default: false

      t.timestamps
    end

    add_index :onboarding_employment_types, :name, unique: true
  end
end
