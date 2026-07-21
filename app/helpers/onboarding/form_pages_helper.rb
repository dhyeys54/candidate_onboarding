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
      badge = extracted_field_badge(candidate_profile, attribute) if candidate_profile

      form.label(attribute, nil, class: form_label_class) do
        safe_join([ text || attribute.to_s.humanize, required_marker(required), badge ].compact)
      end
    end

    def required_marker(required)
      return unless required

      content_tag :span, " *", class: "text-red-500"
    end

    # Renders a candidate_profile string-array attribute (transport_types/working_days) as a
    # checkbox group, plus the trailing hidden fallback field real submissions need so unchecking
    # every box still submits the key (see CandidateProfile#strip_blank_array_values). `data` is for
    # wiring up a Stimulus target/action on each checkbox.
    def checkbox_group(candidate_profile, attribute, options:, label:, grid_class: "grid-cols-2 sm:grid-cols-3", required: false, data: {})
      selected = Array(candidate_profile.public_send(attribute))

      safe_join([
        content_tag(:span, safe_join([ label, required_marker(required) ].compact), class: form_label_class),
        content_tag(:div, class: "mt-1 grid #{grid_class} gap-2") do
          safe_join(
            options.map { |option| checkbox_group_option(attribute, option, selected.include?(option), data) } +
              [ hidden_field_tag("candidate_profile[#{attribute}][]", "") ]
          )
        end,
        field_errors(candidate_profile, attribute)
      ])
    end

    # Same as checkbox_group, but for a DB-backed lookup list (regions/employment_types — see
    # Onboarding::Region/EmploymentType): checkbox values are record ids rather than raw strings, and
    # the field submitted (`name`, e.g. :region_ids) is often not the same as the attribute errors are
    # added to (`error_attribute`, e.g. :regions — see Onboarding::FormPages::JobDetailsPage#validate),
    # since Rails doesn't humanize a plural "_ids" suffix the way it does a singular "_id".
    def lookup_checkbox_group(candidate_profile, name, options:, selected_ids:, label:, error_attribute: name, grid_class: "grid-cols-2 sm:grid-cols-3", required: false, data: {})
      safe_join([
        content_tag(:span, safe_join([ label, required_marker(required) ].compact), class: form_label_class),
        content_tag(:div, class: "mt-1 grid #{grid_class} gap-2") do
          safe_join(
            options.map { |option| lookup_checkbox_group_option(name, option, selected_ids.include?(option.id), data) } +
              [ hidden_field_tag("candidate_profile[#{name}][]", "") ]
          )
        end,
        field_errors(candidate_profile, error_attribute)
      ])
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

    private

    def checkbox_group_option(attribute, option, checked, data)
      content_tag :label, class: "flex items-center gap-2 text-sm text-gray-700" do
        checkbox = check_box_tag "candidate_profile[#{attribute}][]", option, checked,
          id: "candidate_profile_#{attribute}_#{option}", class: "rounded border-gray-300", data: data
        safe_join([ checkbox, option.humanize ])
      end
    end

    def lookup_checkbox_group_option(name, option, checked, data)
      content_tag :label, class: "flex items-center gap-2 text-sm text-gray-700" do
        checkbox = check_box_tag "candidate_profile[#{name}][]", option.id, checked,
          id: "candidate_profile_#{name}_#{option.id}", class: "rounded border-gray-300", data: data
        safe_join([ checkbox, option.name ])
      end
    end
  end
end
