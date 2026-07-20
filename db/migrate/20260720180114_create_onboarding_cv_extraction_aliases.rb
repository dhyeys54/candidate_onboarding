class CreateOnboardingCvExtractionAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_cv_extraction_aliases do |t|
      t.string :field, null: false
      t.string :pattern, null: false
      t.string :value, null: false
      t.integer :match_type, null: false, default: 0

      t.timestamps
    end

    add_index :onboarding_cv_extraction_aliases, %i[field pattern match_type],
              unique: true, name: "index_cv_extraction_aliases_on_field_pattern_match_type"
  end
end
