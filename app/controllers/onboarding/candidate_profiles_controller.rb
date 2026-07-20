module Onboarding
  class CandidateProfilesController < ApplicationController
    before_action :set_candidate_profile

    def show
      @candidate_document = @candidate_profile.candidate_documents.order(created_at: :desc).first
    end

    def edit
    end

    private

    def set_candidate_profile
      @candidate_profile = Onboarding::CandidateProfile.find(params[:id])
    end
  end
end
