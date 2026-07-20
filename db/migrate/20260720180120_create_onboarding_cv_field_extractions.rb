class CreateOnboardingCvFieldExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_cv_field_extractions do |t|
      t.references :candidate_document, null: false, foreign_key: { to_table: :onboarding_candidate_documents }
      t.string :field, null: false
      t.text :extracted_value
      t.integer :confidence, null: false
      t.string :matched_pattern

      t.timestamps
    end
  end
end
