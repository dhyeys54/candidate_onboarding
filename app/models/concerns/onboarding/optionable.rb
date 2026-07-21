module Onboarding
  # Shared behavior for the admin-managed onboarding option lists (job functions, regions, employment
  # types, skills, languages — see Admin::OptionListsController for the parallel shared controller).
  # Doesn't cover `ordered`: some of these order by (:position, :name), others just by (:name), so
  # that scope stays per-model rather than being forced into a shared shape here.
  module Optionable
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
    end

    def to_s
      name
    end
  end
end
