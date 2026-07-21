require "test_helper"

class Onboarding::CvParsing::ProfileMapperTest < ActiveSupport::TestCase
  def build_document(candidate_profile)
    document = candidate_profile.candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("x" * 1.kilobyte), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document
  end

  def build_guest_profile
    Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile
  end

  def value(v, confidence: :high, matched_pattern: "test")
    Onboarding::CvParsing::ExtractedValue.new(value: v, confidence: confidence, matched_pattern: matched_pattern)
  end

  test "applies extracted identity and profile fields, and flips guest role to candidate" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = {
      first_name: value("Jane"),
      last_name: value("van Dijk"),
      email: value("jane@example.com"),
      city: value("Amsterdam")
    }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    user = profile.user.reload
    profile.reload
    assert_equal "Jane", user.first_name
    assert_equal "van Dijk", user.last_name
    assert_equal "jane@example.com", user.email
    assert_predicate user, :candidate?
    assert_equal "Amsterdam", profile.city
    assert_equal({ "city" => "high" }, profile.extracted_fields)
  end

  test "does not overwrite an already-set profile field" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = { job_function: value("specialist") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_equal "general_dentist", profile.job_function
    assert_not profile.extracted_fields.key?("job_function")
  end

  test "applies extracted big_registration_status and years_of_experience" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = {
      big_registration_status: value("big_registered"),
      years_of_experience: value(8)
    }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_equal "big_registered", profile.big_registration_status
    assert_equal 8, profile.years_of_experience
  end

  test "does not overwrite the identity of a non-guest user" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    original_email = profile.user.email
    extracted = { email: value("someone-else@example.com") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_equal original_email, profile.user.reload.email
  end

  test "does not flip role when no identity field is extracted" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { city: value("Amsterdam") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_predicate profile.user.reload, :guest?
  end

  test "flips role when only email (not name) is extracted" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { email: value("jane@example.com") }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_predicate profile.user.reload, :candidate?
  end

  test "logs every extracted field regardless of whether it was applied" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = {
      job_function: value("specialist"),
      phone: value("06-12345678")
    }

    assert_difference "document.cv_field_extractions.count", 2 do
      Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    end

    fields = document.cv_field_extractions.pluck(:field)
    assert_includes fields, "job_function"
    assert_includes fields, "phone"
  end

  test "builds education records from extracted entries when the candidate has none yet" do
    profile = build_guest_profile
    document = build_document(profile)
    entries = [
      { institution: "University of Amsterdam", study: "Dentistry", level: :bachelor,
        start_date: Date.new(2015, 1, 1), end_date: Date.new(2019, 1, 1) }
    ]

    Onboarding::CvParsing::ProfileMapper.new(document, { education_entries: value(entries, confidence: :low) }).call
    profile.reload

    assert_equal 1, profile.educations.count
    education = profile.educations.first
    assert_equal "University of Amsterdam", education.institution
    assert_equal "Dentistry", education.study
    assert_equal "bachelor", education.level
    assert_equal({ "education_entries" => "low" }, profile.extracted_fields)
  end

  test "drops education entries with no discernible study text" do
    profile = build_guest_profile
    document = build_document(profile)
    entries = [ { institution: "University of Amsterdam", study: nil, level: nil, start_date: nil, end_date: nil } ]

    Onboarding::CvParsing::ProfileMapper.new(document, { education_entries: value(entries) }).call

    assert_equal 0, profile.reload.educations.count
  end

  test "does not add education entries when the candidate already has education records" do
    profile = build_guest_profile
    profile.educations.create!(study: "Existing course")
    document = build_document(profile)
    entries = [ { institution: "New Uni", study: "New course", level: :hbo, start_date: nil, end_date: nil } ]

    Onboarding::CvParsing::ProfileMapper.new(document, { education_entries: value(entries) }).call
    profile.reload

    assert_equal 1, profile.educations.count
    assert_equal "Existing course", profile.educations.first.study
  end

  test "builds work experience records from extracted entries when the candidate has none yet" do
    profile = build_guest_profile
    document = build_document(profile)
    entries = [
      { job_title: "Dentist", company_name: "Smile Clinic Amsterdam", responsibilities: "Treated patients",
        start_date: Date.new(2019, 1, 1), end_date: Date.new(2022, 1, 1), current_job: false }
    ]

    Onboarding::CvParsing::ProfileMapper.new(document, { work_experience_entries: value(entries, confidence: :low) }).call
    profile.reload

    assert_equal 1, profile.work_experiences.count
    work_experience = profile.work_experiences.first
    assert_equal "Dentist", work_experience.job_title
    assert_equal "Smile Clinic Amsterdam", work_experience.company_name
    assert_equal({ "work_experience_entries" => "low" }, profile.extracted_fields)
  end

  test "builds one work experience record per extracted employer, not just the first" do
    profile = build_guest_profile
    document = build_document(profile)
    entries = [
      { job_title: "Dentist", company_name: "Smile Clinic Amsterdam", start_date: nil, end_date: nil, current_job: false },
      { job_title: "Junior Dentist", company_name: "Tandartspraktijk Utrecht", start_date: nil, end_date: nil, current_job: false }
    ]

    Onboarding::CvParsing::ProfileMapper.new(document, { work_experience_entries: value(entries) }).call
    profile.reload

    assert_equal 2, profile.work_experiences.count
    assert_equal [ "Smile Clinic Amsterdam", "Tandartspraktijk Utrecht" ], profile.work_experiences.pluck(:company_name)
  end

  test "drops work experience entries with no discernible company name" do
    profile = build_guest_profile
    document = build_document(profile)
    entries = [ { job_title: "Dentist", company_name: nil, start_date: nil, end_date: nil, current_job: false } ]

    Onboarding::CvParsing::ProfileMapper.new(document, { work_experience_entries: value(entries) }).call

    assert_equal 0, profile.reload.work_experiences.count
  end

  test "does not add work experience entries when the candidate already has work experience records" do
    profile = build_guest_profile
    profile.work_experiences.create!(job_title: "Existing role", company_name: "Existing Co")
    document = build_document(profile)
    entries = [ { job_title: "New role", company_name: "New Co", start_date: nil, end_date: nil, current_job: false } ]

    Onboarding::CvParsing::ProfileMapper.new(document, { work_experience_entries: value(entries) }).call
    profile.reload

    assert_equal 1, profile.work_experiences.count
    assert_equal "Existing Co", profile.work_experiences.first.company_name
  end

  test "matches an extracted skill name to the platform skill list scoped to job_function" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = {
      job_function: value("general_dentist"),
      skill_names: value([ "Endodontics" ], confidence: :low)
    }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_includes profile.skills, onboarding_skills(:endodontics)
    assert_equal "low", profile.extracted_fields["skill_names"]
  end

  test "matches an extracted skill name case-insensitively" do
    profile = build_guest_profile
    profile.update!(job_function: "general_dentist")
    document = build_document(profile)
    extracted = { skill_names: value([ "endodontics" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_includes profile.skills, onboarding_skills(:endodontics)
  end

  test "stores an unmatched skill name as a free-text suggestion instead of dropping it" do
    profile = build_guest_profile
    profile.update!(job_function: "general_dentist")
    document = build_document(profile)
    extracted = { skill_names: value([ "3D printing" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    candidate_skill = profile.candidate_skills.sole
    assert_nil candidate_skill.skill_id
    assert_equal "3D printing", candidate_skill.suggested_name
  end

  test "does not match a skill name against a different job_function's skill list" do
    profile = build_guest_profile
    profile.update!(job_function: "dental_technician")
    document = build_document(profile)
    extracted = { skill_names: value([ "Endodontics" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    candidate_skill = profile.candidate_skills.sole
    assert_nil candidate_skill.skill_id
    assert_equal "Endodontics", candidate_skill.suggested_name
  end

  test "does not add skills when the candidate already has skill records" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = { skill_names: value([ "Prevention" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_equal 1, profile.reload.candidate_skills.count
  end

  test "builds candidate_language records from extracted, alias-canonicalized language names" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { language_names: value([ "English", "Dutch" ], confidence: :low) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_equal [ "Dutch", "English" ], profile.languages.pluck(:name).sort
    assert_equal "low", profile.extracted_fields["language_names"]
  end

  test "drops an extracted language name that doesn't match the platform language list" do
    profile = build_guest_profile
    document = build_document(profile)
    extracted = { language_names: value([ "Klingon" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call

    assert_equal 0, profile.reload.languages.count
  end

  test "does not add languages when the candidate already has a language selected" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = build_document(profile)
    extracted = { language_names: value([ "Dutch" ]) }

    Onboarding::CvParsing::ProfileMapper.new(document, extracted).call
    profile.reload

    assert_equal [ "English" ], profile.languages.pluck(:name)
  end

  test "is idempotent across repeated calls" do
    profile = build_guest_profile
    document = build_document(profile)

    Onboarding::CvParsing::ProfileMapper.new(document, { city: value("Amsterdam") }).call
    Onboarding::CvParsing::ProfileMapper.new(document, { city: value("Rotterdam") }).call

    assert_equal "Amsterdam", profile.reload.city
  end
end
