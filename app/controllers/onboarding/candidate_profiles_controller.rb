module Onboarding
  class CandidateProfilesController < ApplicationController
    before_action :set_candidate_profile
    before_action :set_form

    def show
      @candidate_document = @candidate_profile.candidate_documents.order(created_at: :desc).first
    end

    def edit
    end

    def update
      if update_identity! && @candidate_profile.update(candidate_profile_params)
        redirect_to edit_onboarding_candidate_profile_path(@candidate_profile, page: target_page_key)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_candidate_profile
      @candidate_profile = Onboarding::CandidateProfile.find(params[:id])
    end

    def set_form
      @form = Onboarding::Form.new(candidate_profile: @candidate_profile, page_key: params[:page])
    end

    # The current page's own fields live on CandidateProfile; identity (name/email) lives on the
    # associated Onboarding::User instead, so it's saved separately when the page owns any.
    def update_identity!
      return true if @form.page.user_fields.empty?

      @candidate_profile.user.update(params.require(:user).permit(*@form.page.user_fields))
    end

    def candidate_profile_params
      params.require(:candidate_profile).permit(*@form.page.fields)
    end

    def target_page_key
      going_back? ? @form.previous_page&.key : (@form.next_page&.key || @form.page.key)
    end

    def going_back?
      params[:commit] == "Back"
    end
  end
end
