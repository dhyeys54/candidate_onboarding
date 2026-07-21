module Admin
  # Lists candidates who have finished onboarding — drafts mid-flow aren't recruiter-relevant yet
  # and are excluded so recruiters never see partially-entered data.
  class CandidatesController < BaseController
    before_action :set_candidate_profile, only: :show

    def index
      @candidate_profiles = submitted_candidate_profiles.includes(:user).order(created_at: :desc)
    end

    def show
    end

    private

    def set_candidate_profile
      @candidate_profile = submitted_candidate_profiles
        .includes(:user, :educations, :work_experiences, candidate_skills: :skill, candidate_languages: :language)
        .find(params[:id])
    end

    def submitted_candidate_profiles
      Onboarding::CandidateProfile.where(onboarding_status: :submitted)
    end
  end
end
