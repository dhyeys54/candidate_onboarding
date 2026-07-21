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
      # user_fields). Base implementation is a no-op, for pages with nothing to enforce yet. Return
      # value is ignored — this runs as an ActiveModel `validate` callback, so only errors added
      # onto candidate_profile.errors matter.
      def validate(_candidate_profile)
      end

      # Numeric-column attributes silently type-cast non-numeric input (e.g. "abc") to 0 rather than
      # nil, so a plain `.blank?`/presence check never sees garbage input — it looks like a valid 0.
      # Checking the raw *_before_type_cast string catches that. No-ops when nothing was submitted
      # (presence, where required, is each page's own concern).
      def validate_numeric(candidate_profile, attribute, min: nil, max: nil)
        raw = candidate_profile.public_send(:"#{attribute}_before_type_cast")
        return if raw.blank?

        if raw.is_a?(String) && raw !~ /\A-?\d+(\.\d+)?\z/
          candidate_profile.errors.add(attribute, "is not a number")
          return
        end

        value = candidate_profile.public_send(attribute)
        return if value.nil?

        candidate_profile.errors.add(attribute, "must be greater than or equal to #{min}") if min && value < min
        candidate_profile.errors.add(attribute, "must be less than or equal to #{max}") if max && value > max
      end
    end
  end
end
