module Onboarding
  module FormPagesHelper
    def form_label_class
      "block text-sm font-medium text-gray-700"
    end

    # object/attribute are optional so existing `form_input_class` (no-arg) call sites keep working;
    # pass the record and attribute to get the red error-state border once a page has been revamped.
    def form_input_class(object = nil, attribute = nil)
      base = "mt-1 block w-full rounded-lg border px-3 py-2 text-sm shadow-sm focus:ring-indigo-500"

      if object && attribute && object.errors[attribute].any?
        "#{base} border-red-400 focus:border-red-500"
      else
        "#{base} border-gray-300 focus:border-indigo-500"
      end
    end

    # Inline error text for a single field, shown under the input. Pass the actual record the field
    # is bound to (candidate_profile, or candidate_profile.user for identity fields).
    def field_errors(object, attribute)
      return if object.nil?

      messages = object.errors[attribute]
      return if messages.empty?

      content_tag :p, messages.first, class: "mt-1 text-xs text-red-600"
    end

    # Label row for a candidate_profile-backed field: optional required asterisk, plus the "from
    # your CV" badge inline when ProfileMapper pre-filled it. Used instead of a bare form.label
    # across the page partials. `candidate_profile:` is the record extracted_fields lives on, which
    # for identity fields (first_name/last_name/email) is still the candidate_profile, not the user.
    def field_label(form, attribute, text: nil, candidate_profile: nil, required: false)
      content_tag :div, class: "flex items-center justify-between" do
        concat(
          form.label(attribute, nil, class: form_label_class) do
            safe_join([ text || attribute.to_s.humanize, required_marker(required) ].compact)
          end
        )
        concat extracted_field_badge(candidate_profile, attribute) if candidate_profile
      end
    end

    def required_marker(required)
      return unless required

      content_tag :span, " *", class: "text-red-500"
    end

    # Combined error messages for the top-of-page summary banner: candidate_profile's own errors,
    # plus its user's. Skips the "user.*" compound entries that nested-attributes autosave
    # validation imports onto candidate_profile — candidate_profile.user.errors already covers
    # those with a cleaner message, so including both would list the same problem twice.
    def form_error_messages(candidate_profile)
      own = candidate_profile.errors.reject { |error| error.attribute.to_s.start_with?("user.") }.map(&:full_message)
      own + candidate_profile.user.errors.full_messages
    end

    # Small badge shown next to a field CvParsing::ProfileMapper pre-filled, so the candidate can
    # see what came from their CV vs. what they typed. candidate_profile.extracted_fields maps
    # field name => confidence ("high"/"low"), stamped by ProfileMapper#apply_profile_fields.
    def extracted_field_badge(candidate_profile, field)
      confidence = candidate_profile.extracted_fields[field.to_s]
      return unless confidence

      low_confidence = confidence == "low"

      content_tag :span,
        (low_confidence ? "From your CV — please verify" : "From your CV"),
        class: [
          "ml-2 inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
          low_confidence ? "bg-amber-100 text-amber-800" : "bg-indigo-100 text-indigo-800"
        ].join(" ")
    end
  end
end
