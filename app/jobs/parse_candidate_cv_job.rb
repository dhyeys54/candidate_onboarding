class ParseCandidateCvJob < ApplicationJob
  queue_as :default

  def perform(candidate_document_id)
    candidate_document = Onboarding::CandidateDocument.find(candidate_document_id)
    Onboarding::CvParsingService.new(candidate_document).call
  end
end
