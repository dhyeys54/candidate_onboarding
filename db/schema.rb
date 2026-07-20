# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_20_180120) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "onboarding_candidate_documents", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "document_type", default: 0, null: false
    t.bigint "file_size"
    t.string "original_filename"
    t.datetime "parsed_at"
    t.integer "parsing_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_onboarding_candidate_documents_on_candidate_profile_id"
  end

  create_table "onboarding_candidate_languages", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.bigint "language_id", null: false
    t.integer "proficiency"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "language_id"], name: "index_onboarding_candidate_languages_on_profile_and_language", unique: true
    t.index ["candidate_profile_id"], name: "index_onboarding_candidate_languages_on_candidate_profile_id"
    t.index ["language_id"], name: "index_onboarding_candidate_languages_on_language_id"
  end

  create_table "onboarding_candidate_profiles", force: :cascade do |t|
    t.date "available_from"
    t.integer "average_daily_revenue"
    t.string "big_number"
    t.integer "big_registration_status"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "desired_gross_salary"
    t.decimal "desired_percentage", precision: 5, scale: 2
    t.string "employment_types", default: [], null: false, array: true
    t.jsonb "extracted_fields", default: {}, null: false
    t.text "internal_notes"
    t.integer "job_function"
    t.integer "max_travel_time_minutes"
    t.text "motivation_for_employer"
    t.string "notice_period"
    t.integer "onboarding_status", default: 0, null: false
    t.string "phone"
    t.text "reason_for_change"
    t.text "reason_for_looking"
    t.string "regions", default: [], null: false, array: true
    t.integer "search_status"
    t.text "suggested_summary"
    t.string "transport_types", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "working_days", default: [], null: false, array: true
    t.integer "years_of_experience"
    t.index ["user_id"], name: "index_onboarding_candidate_profiles_on_user_id", unique: true
  end

  create_table "onboarding_candidate_skills", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.bigint "skill_id"
    t.string "suggested_name"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "skill_id"], name: "index_onboarding_candidate_skills_on_profile_and_skill", unique: true
    t.index ["candidate_profile_id"], name: "index_onboarding_candidate_skills_on_candidate_profile_id"
    t.index ["skill_id"], name: "index_onboarding_candidate_skills_on_skill_id"
  end

  create_table "onboarding_cv_extraction_aliases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field", null: false
    t.integer "match_type", default: 0, null: false
    t.string "pattern", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["field", "pattern", "match_type"], name: "index_cv_extraction_aliases_on_field_pattern_match_type", unique: true
  end

  create_table "onboarding_cv_field_extractions", force: :cascade do |t|
    t.bigint "candidate_document_id", null: false
    t.integer "confidence", null: false
    t.datetime "created_at", null: false
    t.text "extracted_value"
    t.string "field", null: false
    t.string "matched_pattern"
    t.datetime "updated_at", null: false
    t.index ["candidate_document_id"], name: "index_onboarding_cv_field_extractions_on_candidate_document_id"
  end

  create_table "onboarding_educations", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "institution"
    t.integer "level"
    t.string "location"
    t.date "start_date"
    t.string "study", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_onboarding_educations_on_candidate_profile_id"
  end

  create_table "onboarding_languages", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_onboarding_languages_on_name", unique: true
  end

  create_table "onboarding_skills", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "job_function"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "job_function"], name: "index_onboarding_skills_on_name_and_job_function", unique: true
  end

  create_table "onboarding_work_experiences", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.boolean "current_job", default: false, null: false
    t.date "end_date"
    t.string "job_title", null: false
    t.text "responsibilities"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_onboarding_work_experiences_on_candidate_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "onboarding_candidate_documents", "onboarding_candidate_profiles", column: "candidate_profile_id"
  add_foreign_key "onboarding_candidate_languages", "onboarding_candidate_profiles", column: "candidate_profile_id"
  add_foreign_key "onboarding_candidate_languages", "onboarding_languages", column: "language_id"
  add_foreign_key "onboarding_candidate_profiles", "users"
  add_foreign_key "onboarding_candidate_skills", "onboarding_candidate_profiles", column: "candidate_profile_id"
  add_foreign_key "onboarding_candidate_skills", "onboarding_skills", column: "skill_id"
  add_foreign_key "onboarding_cv_field_extractions", "onboarding_candidate_documents", column: "candidate_document_id"
  add_foreign_key "onboarding_educations", "onboarding_candidate_profiles", column: "candidate_profile_id"
  add_foreign_key "onboarding_work_experiences", "onboarding_candidate_profiles", column: "candidate_profile_id"
end
