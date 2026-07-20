require "test_helper"

class Onboarding::CandidateProfileTest < ActiveSupport::TestCase
  def new_profile(attrs = {})
    Onboarding::User.create!(first_name: "Jamie", last_name: "Doe", email: "jamie.doe.#{SecureRandom.hex(4)}@example.com")
      .build_candidate_profile(attrs)
  end

  test "draft context does not require any of the submission-only fields" do
    profile = new_profile

    assert profile.valid?(:draft)
  end

  test "submission context requires the core PRD fields" do
    profile = new_profile

    assert_not profile.valid?(:submission)
    %i[phone city country job_function max_travel_time_minutes search_status
       years_of_experience available_from].each do |attribute|
      assert_includes profile.errors.attribute_names, attribute, "expected #{attribute} to be required"
    end
  end

  test "submission context requires at least one region, employment type, working day, and language" do
    profile = new_profile

    assert_not profile.valid?(:submission)
    assert_includes profile.errors.attribute_names, :regions
    assert_includes profile.errors.attribute_names, :employment_types
    assert_includes profile.errors.attribute_names, :working_days
    assert_includes profile.errors.attribute_names, :languages
  end

  test "rejects region, employment type, transport type, and working day values outside the fixed lists" do
    profile = new_profile(regions: [ "atlantis" ], employment_types: [ "volunteer" ],
                           transport_types: [ "teleport" ], working_days: [ "someday" ])

    assert_not profile.valid?
    assert_includes profile.errors.attribute_names, :regions
    assert_includes profile.errors.attribute_names, :employment_types
    assert_includes profile.errors.attribute_names, :transport_types
    assert_includes profile.errors.attribute_names, :working_days
  end

  test "requires desired_gross_salary when an employment type is salary-relevant" do
    profile = new_profile(employment_types: [ "employed" ])

    assert_not profile.valid?(:submission)
    assert_includes profile.errors.attribute_names, :desired_gross_salary
    assert_not_includes profile.errors.attribute_names, :desired_percentage
  end

  test "requires desired_percentage when an employment type is percentage-relevant" do
    profile = new_profile(employment_types: [ "self_employed" ])

    assert_not profile.valid?(:submission)
    assert_includes profile.errors.attribute_names, :desired_percentage
    assert_not_includes profile.errors.attribute_names, :desired_gross_salary
  end

  test "requires average_daily_revenue and big_registration_status for revenue/BIG-relevant job functions" do
    profile = new_profile(job_function: :dental_hygienist)

    assert_not profile.valid?(:submission)
    assert_includes profile.errors.attribute_names, :average_daily_revenue
    assert_includes profile.errors.attribute_names, :big_registration_status
  end

  test "does not require average_daily_revenue or big_registration_status for non-relevant job functions" do
    profile = new_profile(job_function: :practice_manager)

    profile.valid?(:submission)
    assert_not_includes profile.errors.attribute_names, :average_daily_revenue
    assert_not_includes profile.errors.attribute_names, :big_registration_status
  end

  test "requires big_number when big_registration_status is big_registered" do
    profile = new_profile(big_registration_status: :big_registered)

    assert_not profile.valid?(:submission)
    assert_includes profile.errors.attribute_names, :big_number
  end

  test "a fully filled-out profile passes submission validation" do
    profile = new_profile(
      phone: "+31 6 1234 5678", city: "Amsterdam", country: "Netherlands",
      job_function: :dental_technician, regions: [ "north" ], max_travel_time_minutes: 30,
      search_status: :active, employment_types: [ "employed" ], years_of_experience: 5,
      desired_gross_salary: 4000, working_days: [ "monday", "tuesday" ], available_from: Date.tomorrow
    )
    profile.save!
    profile.candidate_languages.create!(language: onboarding_languages(:dutch))

    assert profile.valid?(:submission), profile.errors.full_messages.to_sentence
  end

  test "has_many skills through candidate_skills" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.skills, onboarding_skills(:endodontics)
  end

  test "has_many languages through candidate_languages" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.languages, onboarding_languages(:english)
  end

  test "defaults onboarding_status to draft" do
    profile = new_profile

    assert profile.draft?
  end

  test "has_many candidate_documents" do
    profile = onboarding_candidate_profiles(:draft_profile)
    document = profile.candidate_documents.build
    document.file.attach(io: StringIO.new("x"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!

    assert_includes profile.reload.candidate_documents, document
  end
end
