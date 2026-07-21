module Admin
  class RegionsController < OptionListsController
    private

    def resource_class
      Onboarding::Region
    end

    def permitted_attributes
      %i[name active position]
    end

    def index_path
      admin_regions_path
    end
  end
end
