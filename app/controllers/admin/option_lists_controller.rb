module Admin
  # Shared CRUD shape for the admin-managed onboarding option lists (job functions, regions,
  # employment types, skills, languages) — these were hardcoded Ruby constants/enums until now (see
  # Onboarding::JobFunction/Region/EmploymentType), so recruiters can no longer add or retire a value
  # without a code deploy. Concrete subclasses just declare resource_class/permitted_attributes/
  # index_path; this class owns the five actions and their shared error handling. Abstract — not
  # routed directly.
  class OptionListsController < BaseController
    before_action :set_resource, only: %i[edit update destroy]

    def index
      @resources = resource_class.ordered
    end

    def new
      @resource = resource_class.new
    end

    def create
      @resource = resource_class.new(resource_params)

      if @resource.save
        redirect_to index_path, notice: "#{resource_class.model_name.human} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @resource.update(resource_params)
        redirect_to index_path, notice: "#{resource_class.model_name.human} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @resource.destroy
        redirect_to index_path, notice: "#{resource_class.model_name.human} deleted."
      else
        redirect_to index_path, alert: @resource.errors.full_messages.to_sentence
      end
    end

    private

    def set_resource
      @resource = resource_class.find(params[:id])
    end

    def resource_params
      params.require(resource_class.model_name.param_key.to_sym).permit(*permitted_attributes)
    end

    def resource_class
      raise NotImplementedError
    end

    def permitted_attributes
      raise NotImplementedError
    end

    def index_path
      raise NotImplementedError
    end
  end
end
