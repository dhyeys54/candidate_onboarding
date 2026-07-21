module Admin
  class EmploymentTypesController < OptionListsController
    private

    def resource_class
      Onboarding::EmploymentType
    end

    def permitted_attributes
      %i[name active position salary_relevant percentage_relevant]
    end

    def index_path
      admin_employment_types_path
    end
  end
end
