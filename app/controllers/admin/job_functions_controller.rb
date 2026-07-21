module Admin
  class JobFunctionsController < OptionListsController
    private

    def resource_class
      Onboarding::JobFunction
    end

    def permitted_attributes
      %i[key name active position big_relevant revenue_relevant]
    end

    def index_path
      admin_job_functions_path
    end
  end
end
