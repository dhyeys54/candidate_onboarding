class CreateOnboardingCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_candidate_profiles do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }, index: { unique: true }

      # Personal details
      t.string :phone
      t.string :city
      t.string :country

      # Job preferences
      t.integer :job_function
      t.string :regions, array: true, null: false, default: []
      t.integer :max_travel_time_minutes
      t.string :transport_types, array: true, null: false, default: []
      t.integer :search_status
      t.text :reason_for_looking

      # Employment & compensation
      t.string :employment_types, array: true, null: false, default: []
      t.integer :years_of_experience
      t.integer :desired_gross_salary
      t.decimal :desired_percentage, precision: 5, scale: 2
      t.integer :average_daily_revenue
      t.integer :big_registration_status
      t.string :big_number

      # Availability
      t.string :working_days, array: true, null: false, default: []
      t.date :available_from
      t.string :notice_period

      # Additional information
      t.text :motivation_for_employer
      t.text :internal_notes
      t.text :suggested_summary
      t.text :reason_for_change

      # Meta
      t.integer :onboarding_status, null: false, default: 0
      t.jsonb :extracted_fields, null: false, default: {}

      t.timestamps
    end
  end
end
