class MigrateJobFunctionAndOptionListsToLookupTables < ActiveRecord::Migration[8.1]
  # Matches the pre-existing Onboarding::JobFunctions::VALUES integer mapping (insertion order here
  # determines the new row's id, which the int -> id backfill below relies on being int + 1).
  JOB_FUNCTIONS = [
    { key: "general_dentist", name: "General Dentist", big_relevant: true, revenue_relevant: true },
    { key: "dental_hygienist", name: "Dental Hygienist", big_relevant: true, revenue_relevant: true },
    { key: "dental_assistant", name: "Dental Assistant" },
    { key: "prevention_assistant", name: "Prevention Assistant" },
    { key: "paro_prevention_assistant", name: "Paro Prevention Assistant" },
    { key: "orthodontic_assistant", name: "Orthodontic Assistant" },
    { key: "front_office_receptionist", name: "Front Office Receptionist" },
    { key: "practice_manager", name: "Practice Manager" },
    { key: "dental_technician", name: "Dental Technician" },
    { key: "specialist", name: "Specialist", big_relevant: true, revenue_relevant: true }
  ].freeze

  REGIONS = %w[North South East West Central].freeze

  EMPLOYMENT_TYPES = [
    { name: "Employed", salary_relevant: true },
    { name: "Self Employed", percentage_relevant: true },
    { name: "Freelance", percentage_relevant: true },
    { name: "Percentage Based", percentage_relevant: true }
  ].freeze

  def up
    add_reference :onboarding_candidate_profiles, :job_function, foreign_key: { to_table: :onboarding_job_functions }
    add_reference :onboarding_skills, :job_function, foreign_key: { to_table: :onboarding_job_functions }

    JOB_FUNCTIONS.each_with_index do |attrs, index|
      execute <<~SQL.squish
        INSERT INTO onboarding_job_functions (key, name, position, big_relevant, revenue_relevant, created_at, updated_at)
        VALUES (#{quote(attrs[:key])}, #{quote(attrs[:name])}, #{index}, #{attrs[:big_relevant] ? true : false}, #{attrs[:revenue_relevant] ? true : false}, now(), now())
      SQL
    end

    REGIONS.each_with_index do |name, index|
      execute <<~SQL.squish
        INSERT INTO onboarding_regions (name, position, created_at, updated_at)
        VALUES (#{quote(name)}, #{index}, now(), now())
      SQL
    end

    EMPLOYMENT_TYPES.each_with_index do |attrs, index|
      execute <<~SQL.squish
        INSERT INTO onboarding_employment_types (name, position, salary_relevant, percentage_relevant, created_at, updated_at)
        VALUES (#{quote(attrs[:name])}, #{index}, #{attrs[:salary_relevant] ? true : false}, #{attrs[:percentage_relevant] ? true : false}, now(), now())
      SQL
    end

    # JOB_FUNCTIONS was inserted in exactly the old enum's integer order into an empty table, so the
    # new row's id is always old_int + 1 — no name/key lookup needed for this backfill.
    execute "UPDATE onboarding_candidate_profiles SET job_function_id = job_function + 1 WHERE job_function IS NOT NULL"
    execute "UPDATE onboarding_skills SET job_function_id = job_function + 1 WHERE job_function IS NOT NULL"

    execute <<~SQL.squish
      INSERT INTO onboarding_candidate_regions (candidate_profile_id, region_id, created_at, updated_at)
      SELECT cp.id, r.id, now(), now()
      FROM onboarding_candidate_profiles cp
      CROSS JOIN LATERAL unnest(cp.regions) AS region_name
      JOIN onboarding_regions r ON r.name = region_name
    SQL

    execute <<~SQL.squish
      INSERT INTO onboarding_candidate_employment_types (candidate_profile_id, employment_type_id, created_at, updated_at)
      SELECT cp.id, et.id, now(), now()
      FROM onboarding_candidate_profiles cp
      CROSS JOIN LATERAL unnest(cp.employment_types) AS employment_type_name
      JOIN onboarding_employment_types et ON et.name = employment_type_name
    SQL

    remove_column :onboarding_candidate_profiles, :job_function, :integer
    remove_column :onboarding_candidate_profiles, :regions
    remove_column :onboarding_candidate_profiles, :employment_types
    remove_column :onboarding_skills, :job_function, :integer
  end

  def down
    add_column :onboarding_candidate_profiles, :job_function, :integer
    add_column :onboarding_candidate_profiles, :regions, :string, array: true, null: false, default: []
    add_column :onboarding_candidate_profiles, :employment_types, :string, array: true, null: false, default: []
    add_column :onboarding_skills, :job_function, :integer

    execute "UPDATE onboarding_candidate_profiles SET job_function = job_function_id - 1 WHERE job_function_id IS NOT NULL"
    execute "UPDATE onboarding_skills SET job_function = job_function_id - 1 WHERE job_function_id IS NOT NULL"

    execute <<~SQL.squish
      UPDATE onboarding_candidate_profiles cp
      SET regions = sub.names
      FROM (
        SELECT cr.candidate_profile_id, array_agg(r.name) AS names
        FROM onboarding_candidate_regions cr
        JOIN onboarding_regions r ON r.id = cr.region_id
        GROUP BY cr.candidate_profile_id
      ) sub
      WHERE sub.candidate_profile_id = cp.id
    SQL

    execute <<~SQL.squish
      UPDATE onboarding_candidate_profiles cp
      SET employment_types = sub.names
      FROM (
        SELECT ce.candidate_profile_id, array_agg(et.name) AS names
        FROM onboarding_candidate_employment_types ce
        JOIN onboarding_employment_types et ON et.id = ce.employment_type_id
        GROUP BY ce.candidate_profile_id
      ) sub
      WHERE sub.candidate_profile_id = cp.id
    SQL

    remove_reference :onboarding_candidate_profiles, :job_function, foreign_key: { to_table: :onboarding_job_functions }
    remove_reference :onboarding_skills, :job_function, foreign_key: { to_table: :onboarding_job_functions }
  end
end
