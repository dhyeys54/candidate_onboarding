module Onboarding
  class CandidateProfilesController < ApplicationController
    include Onboarding::CandidateAuthorization

    before_action :set_candidate_profile
    before_action :authorize_candidate!
    before_action :set_form

    def show
      @candidate_document = @candidate_profile.candidate_documents.order(created_at: :desc).first
    end

    def edit
    end

    def update
      @candidate_profile.assign_attributes(step_attributes)

      if @candidate_profile.save(context: going_back? ? nil : @form.page.key)
        Onboarding::CompleteCandidateProfileService.new(@candidate_profile).call if @form.last_page? && !going_back?
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

    def step_attributes
      permitted = @form.page.fields.dup
      permitted << { user_attributes: [ :id, *@form.page.user_fields ] } if @form.page.user_fields.any?

      params.require(:candidate_profile).permit(*permitted)
    end

    def target_page_key
      going_back? ? @form.previous_page&.key : (@form.next_page&.key || @form.page.key)
    end

    def going_back?
      params[:direction] == "back"
    end
  end
end
