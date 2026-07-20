module Onboarding
  module CvParsing
    # Applies FieldExtractor's output to the Onboarding::User/CandidateProfile behind a
    # CandidateDocument. Idempotent: only ever fills currently-blank attributes (never overwrites
    # something the candidate already has), and logs every extraction attempt regardless of whether
    # it was applied.
    class ProfileMapper
      USER_FIELDS = %i[first_name last_name email].freeze
      PROFILE_FIELDS = %i[phone city country job_function big_number suggested_summary].freeze
      GUEST_EMAIL_PATTERN = /\Aguest-[0-9a-f-]{36}@guest\.dentalonboarding\.invalid\z/

      def initialize(candidate_document, extracted_fields)
        @candidate_document = candidate_document
        @candidate_profile = candidate_document.candidate_profile
        @user = candidate_profile.user
        @extracted_fields = extracted_fields
      end

      def call
        ActiveRecord::Base.transaction do
          log_extractions
          identity_applied = apply_user_fields
          apply_profile_fields
          user.update!(role: :candidate) if identity_applied && user.guest?
        end
      end

      private

      attr_reader :candidate_document, :candidate_profile, :user, :extracted_fields

      def log_extractions
        extracted_fields.each do |field, extracted|
          candidate_document.cv_field_extractions.create!(
            field: field.to_s,
            extracted_value: extracted.value.to_s,
            confidence: extracted.confidence,
            matched_pattern: extracted.matched_pattern
          )
        end
      end

      def apply_user_fields
        applied = false

        USER_FIELDS.each do |field|
          extracted = extracted_fields[field]
          next unless extracted && user_field_blank?(field)

          user.public_send("#{field}=", extracted.value)
          applied = true
        end

        user.save! if user.changed?
        applied
      end

      def user_field_blank?(field)
        case field
        when :first_name then user.first_name == "Guest"
        when :last_name then user.last_name == "Candidate"
        when :email then user.email.match?(GUEST_EMAIL_PATTERN)
        end
      end

      def apply_profile_fields
        applied_confidences = {}

        PROFILE_FIELDS.each do |field|
          extracted = extracted_fields[field]
          next if extracted.nil? || candidate_profile.public_send(field).present?

          candidate_profile.public_send("#{field}=", extracted.value)
          applied_confidences[field.to_s] = extracted.confidence.to_s
        end

        return if applied_confidences.empty?

        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge(applied_confidences)
        candidate_profile.save!
      end
    end
  end
end
