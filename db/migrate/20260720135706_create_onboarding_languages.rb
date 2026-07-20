class CreateOnboardingLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_languages do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :onboarding_languages, :name, unique: true
  end
end
