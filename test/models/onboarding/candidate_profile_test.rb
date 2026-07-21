require "test_helper"

class Onboarding::CandidateProfileTest < ActiveSupport::TestCase
  def new_profile(attrs = {})
    Onboarding::User.create!(first_name: "Jamie", last_name: "Doe", email: "jamie.doe.#{SecureRandom.hex(4)}@example.com")
      .build_candidate_profile(attrs)
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
