module Onboarding
  # Abstract base for a single step of the candidate onboarding review form. Each subclass
  # declares its key/title/partial and which fields it owns, so Onboarding::Form can drive
  # navigation and the controller can build strong params generically instead of hardcoding a
  # permit list per page.
  class FormPage
    class << self
      attr_accessor :key, :title, :partial

      def fields(*names)
        @fields ||= []
        @fields.concat(names)
        @fields
      end

      def user_fields(*names)
        @user_fields ||= []
        @user_fields.concat(names)
        @user_fields
      end

      # Per-page validation hook, invoked by CandidateProfile#run_current_page_validation when the
      # model is validated/saved under this page's context (its `key`). Subclasses override to add
      # errors directly onto candidate_profile (and/or candidate_profile.user, for pages that own
      # user_fields). Base implementation is a no-op, for pages with nothing to enforce yet.
      def validate(_candidate_profile)
        true
      end
    end
  end
end
