module Onboarding
  module CvParsing
    # Applies FieldExtractor's output to the Onboarding::User/CandidateProfile behind a
    # CandidateDocument. Idempotent: only ever fills currently-blank attributes (never overwrites
    # something the candidate already has), and logs every extraction attempt regardless of whether
    # it was applied.
    class ProfileMapper
      USER_FIELDS = %i[first_name last_name email].freeze
      PROFILE_FIELDS = %i[
        phone city country big_number big_registration_status years_of_experience suggested_summary
      ].freeze
      JOB_FUNCTION_FIELD = :job_function
      EDUCATION_ENTRIES_FIELD = :education_entries
      WORK_EXPERIENCE_ENTRIES_FIELD = :work_experience_entries
      SKILL_NAMES_FIELD = :skill_names
      LANGUAGE_NAMES_FIELD = :language_names

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
          apply_job_function
          apply_profile_fields
          apply_skill_entries
          apply_language_entries
          apply_education_entries
          apply_work_experience_entries
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
        user.guest_placeholder?(field)
      end

      # job_function is handled separately from the generic PROFILE_FIELDS loop because the extracted
      # value is a stable Onboarding::JobFunction#key string (from the CvExtractionAlias dictionary —
      # see FieldExtractor), not something that can be mass-assigned directly to the job_function_id
      # column/belongs_to association.
      def apply_job_function
        extracted = extracted_fields[JOB_FUNCTION_FIELD]
        return if extracted.nil? || candidate_profile.job_function_id.present?

        job_function = Onboarding::JobFunction.find_by(key: extracted.value)
        return unless job_function

        candidate_profile.job_function = job_function
        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge("job_function_id" => extracted.confidence.to_s)
        candidate_profile.save!
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

      # Only prefills when the candidate has no skill rows yet (idempotent, mirrors the other apply_*
      # methods). Runs after apply_profile_fields so candidate_profile.job_function (itself possibly
      # just extracted) is available to scope matching. Each raw CV skill name is matched
      # case-insensitively against the platform Skill list for that job_function; a match becomes a
      # real skill_id reference, anything unmatched becomes a free-text suggested_name row for
      # recruiter review — CandidateSkill accepts either.
      def apply_skill_entries
        extracted = extracted_fields[SKILL_NAMES_FIELD]
        return if extracted.nil? || candidate_profile.candidate_skills.any?

        names = Array(extracted.value).reject(&:blank?).uniq { |name| name.downcase }
        return if names.empty?

        known_skills = candidate_profile.job_function_id.present? ? Onboarding::Skill.where(job_function_id: candidate_profile.job_function_id) : Onboarding::Skill.none
        skills_by_name = known_skills.index_by { |skill| skill.name.downcase }

        names.each do |name|
          matched_skill = skills_by_name[name.downcase]
          candidate_profile.candidate_skills.build(matched_skill ? { skill: matched_skill } : { suggested_name: name })
        end

        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge(
          SKILL_NAMES_FIELD.to_s => extracted.confidence.to_s
        )
        candidate_profile.save!
      end

      # Only prefills when the candidate has no languages selected yet (idempotent, mirrors the other
      # apply_* methods). FieldExtractor already canonicalized names via the "language" alias
      # dictionary, so this only needs an exact (case-insensitive) match against the platform
      # Language list — anything unmatched is dropped, since CandidateLanguage (unlike CandidateSkill)
      # has no free-text fallback column to hold an unrecognized name for review.
      def apply_language_entries
        extracted = extracted_fields[LANGUAGE_NAMES_FIELD]
        return if extracted.nil? || candidate_profile.any_languages_selected?

        known_languages = Onboarding::Language.where(active: true).index_by { |language| language.name.downcase }
        matched = Array(extracted.value).filter_map { |name| known_languages[name.to_s.downcase] }
        return if matched.empty?

        matched.each { |language| candidate_profile.candidate_languages.build(language: language) }
        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge(
          LANGUAGE_NAMES_FIELD.to_s => extracted.confidence.to_s
        )
        candidate_profile.save!
      end

      # Only prefills when the candidate has no education rows yet (idempotent, mirrors
      # apply_profile_fields' blank-only rule) — a re-parse or a second CV upload never duplicates or
      # overwrites education the candidate already reviewed/edited. Entries with no discernible study
      # text are dropped rather than built, since Education requires study to save.
      def apply_education_entries
        extracted = extracted_fields[EDUCATION_ENTRIES_FIELD]
        return if extracted.nil? || candidate_profile.educations.any?

        entries = Array(extracted.value).select { |entry| entry[:study].present? }
        return if entries.empty?

        entries.each { |entry| candidate_profile.educations.build(entry) }
        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge(
          EDUCATION_ENTRIES_FIELD.to_s => extracted.confidence.to_s
        )
        candidate_profile.save!
      end

      # Only prefills when the candidate has no work experience rows yet (idempotent, mirrors
      # apply_education_entries). Supports multiple past employers: every extracted entry is built as
      # its own record rather than collapsing to a single job. Entries with no discernible company name
      # are dropped rather than built, since WorkExperience requires company_name to save.
      def apply_work_experience_entries
        extracted = extracted_fields[WORK_EXPERIENCE_ENTRIES_FIELD]
        return if extracted.nil? || candidate_profile.work_experiences.any?

        entries = Array(extracted.value).select { |entry| entry[:company_name].present? }
        return if entries.empty?

        entries.each { |entry| candidate_profile.work_experiences.build(entry) }
        candidate_profile.extracted_fields = candidate_profile.extracted_fields.merge(
          WORK_EXPERIENCE_ENTRIES_FIELD.to_s => extracted.confidence.to_s
        )
        candidate_profile.save!
      end
    end
  end
end
