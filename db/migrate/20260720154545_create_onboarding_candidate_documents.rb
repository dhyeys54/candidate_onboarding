class CreateOnboardingCandidateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_documents do |t|
      t.references :candidate_profile, null: false, foreign_key: { to_table: :onboarding_candidate_profiles }
      t.integer :document_type, null: false, default: 0
      t.string :original_filename
      t.string :content_type
      t.bigint :file_size
      t.datetime :parsed_at
      t.integer :parsing_status, null: false, default: 0

      t.timestamps
    end
  end
end
