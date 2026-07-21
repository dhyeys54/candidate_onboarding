require "test_helper"

class Onboarding::CandidateProfileTest < ActiveSupport::TestCase
  def new_profile(attrs = {})
    Onboarding::User.create!(first_name: "Jamie", last_name: "Doe", email: "jamie.doe.#{SecureRandom.hex(4)}@example.com")
      .build_candidate_profile(attrs)
  end

  test "rejects transport type and working day values outside the fixed lists" do
    profile = new_profile(transport_types: [ "teleport" ], working_days: [ "someday" ])

    assert_not profile.valid?
    assert_includes profile.errors.attribute_names, :transport_types
    assert_includes profile.errors.attribute_names, :working_days
  end

  test "has_many skills through candidate_skills" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.skills, onboarding_skills(:endodontics)
  end

  test "has_many languages through candidate_languages" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.languages, onboarding_languages(:english)
  end

  test "has_many regions through candidate_regions" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.regions, onboarding_regions(:north)
  end

  test "has_many employment_types through candidate_employment_types" do
    profile = onboarding_candidate_profiles(:draft_profile)

    assert_includes profile.employment_types, onboarding_employment_types(:employed)
  end

  test "region_ids= builds and saves new candidate_regions without touching existing ones" do
    profile = onboarding_candidate_profiles(:draft_profile)

    profile.region_ids = [ onboarding_regions(:north).id, onboarding_regions(:south).id ]
    profile.save!(context: nil)

    assert_equal [ "North", "South" ], profile.reload.regions.pluck(:name).sort
  end

  test "region_ids= removes deselected regions" do
    profile = onboarding_candidate_profiles(:draft_profile)

    profile.region_ids = []
    profile.save!(context: nil)

    assert_empty profile.reload.regions
  end

  test "region_ids= does not persist to the database until saved" do
    profile = onboarding_candidate_profiles(:draft_profile)

    profile.region_ids = [ onboarding_regions(:south).id ]

    assert_equal [ "North" ], Onboarding::CandidateProfile.find(profile.id).regions.pluck(:name)
  end

  test "any_regions_selected? counts newly built, not-yet-persisted candidate_regions" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.candidate_regions.destroy_all
    profile.region_ids = [ onboarding_regions(:south).id ]

    assert profile.any_regions_selected?
  end

  test "any_employment_types_selected? counts newly built, not-yet-persisted candidate_employment_types" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.candidate_employment_types.destroy_all
    profile.employment_type_ids = [ onboarding_employment_types(:freelance).id ]

    assert profile.any_employment_types_selected?
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
