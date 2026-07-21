module Admin
  class SkillsController < OptionListsController
    before_action :set_job_functions, only: %i[new create edit update]

    private

    def set_job_functions
      @job_functions = Onboarding::JobFunction.active.ordered
    end

    def resource_class
      Onboarding::Skill
    end

    def permitted_attributes
      %i[name job_function_id active]
    end

    def index_path
      admin_skills_path
    end
  end
end
