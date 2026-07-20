require "test_helper"

class ParseCandidateCvJobTest < ActiveJob::TestCase
  test "delegates to Onboarding::CvParsingService for the given document" do
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("%PDF-1.4\nreal content"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!

    perform_enqueued_jobs do
      ParseCandidateCvJob.perform_later(document.id)
    end

    assert_predicate document.reload, :completed?
  end
end
