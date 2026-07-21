module Admin
  class LanguagesController < OptionListsController
    private

    def resource_class
      Onboarding::Language
    end

    def permitted_attributes
      %i[name active]
    end

    def index_path
      admin_languages_path
    end
  end
end
