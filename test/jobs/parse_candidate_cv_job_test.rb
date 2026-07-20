require "test_helper"

class ParseCandidateCvJobTest < ActiveJob::TestCase
  test "delegates to Onboarding::CvParsingService for the given document" do
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(
      io: file_fixture("cvs/sample_cv.docx").open,
      filename: "cv.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    document.save!

    perform_enqueued_jobs do
      ParseCandidateCvJob.perform_later(document.id)
    end

    assert_predicate document.reload, :completed?
  end
end
