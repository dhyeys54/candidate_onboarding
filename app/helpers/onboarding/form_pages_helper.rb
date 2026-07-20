module Onboarding
  module FormPagesHelper
    def form_label_class
      "block text-sm font-medium text-gray-700"
    end

    def form_input_class
      "mt-1 block w-full rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
    end

    # Label row for a candidate_profile-backed field, with the "from your CV" badge inline when
    # ProfileMapper pre-filled it. Used instead of a bare form.label across the page partials.
    def field_label(form, attribute, candidate_profile: nil)
      content_tag :div, class: "flex items-center justify-between" do
        concat form.label(attribute, class: form_label_class)
        concat extracted_field_badge(candidate_profile, attribute) if candidate_profile
      end
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
