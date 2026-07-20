require "test_helper"

class Onboarding::UploadCvServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @candidate_profile = onboarding_candidate_profiles(:draft_profile)
  end

  def uploaded_file(fixture_name, content_type:, size: nil)
    tempfile = Tempfile.new(fixture_name)
    tempfile.binmode
    tempfile.write(file_fixture(fixture_name).read)
    tempfile.rewind

    file = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: fixture_name, type: content_type)
    file.instance_variable_get(:@tempfile).define_singleton_method(:size) { size } if size
    file
  end

  test "attaches the file and enqueues parsing on success" do
    assert_enqueued_with(job: ParseCandidateCvJob) do
      result = Onboarding::UploadCvService.new(
        candidate_profile: @candidate_profile,
        uploaded_file: uploaded_file("sample_cv.pdf", content_type: "application/pdf")
      ).call

      assert result.success?
      assert result.candidate_document.file.attached?
      assert_equal "sample_cv.pdf", result.candidate_document.original_filename
      assert_predicate result.candidate_document, :pending?
    end
  end

  test "rejects a disallowed content type without attaching or enqueuing anything" do
    assert_no_enqueued_jobs do
      result = Onboarding::UploadCvService.new(
        candidate_profile: @candidate_profile,
        uploaded_file: uploaded_file("sample_cv.txt", content_type: "text/plain")
      ).call

      assert_not result.success?
      assert_includes result.errors.join, "PDF or Word document"
    end

    assert_equal 0, @candidate_profile.candidate_documents.count
  end

  test "rejects a file over the configured max size" do
    oversized = uploaded_file(
      "sample_cv.pdf",
      content_type: "application/pdf",
      size: Rails.application.config.x.cv_upload.max_size + 1
    )

    result = Onboarding::UploadCvService.new(candidate_profile: @candidate_profile, uploaded_file: oversized).call

    assert_not result.success?
    assert_includes result.errors.join, "too large"
  end

  test "fails when no file is given" do
    result = Onboarding::UploadCvService.new(candidate_profile: @candidate_profile, uploaded_file: nil).call

    assert_not result.success?
    assert_includes result.errors.join, "choose a CV file"
  end
end
