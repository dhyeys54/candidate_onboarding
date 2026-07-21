module Onboarding
  module CvParsing
    # Rule-based (regex/heuristic) extraction of CandidateProfile/User fields from raw CV text. Pure
    # text-in, hash-out — no AR writes here, see ProfileMapper for that. Ambiguous scalar fields
    # (job_function, city, country) are matched against the Onboarding::CvExtractionAlias dictionary
    # rather than hardcoded lists, so the alias table can grow without touching this class.
    # :education_entries and :work_experience_entries are non-scalar fields: each value is an array
    # of hashes (education: institution/study/level/start_date/end_date; work experience: job_title/
    # company_name/responsibilities/start_date/end_date/current_job), best-effort parsed from their
    # respective CV sections. A CV can list several jobs, so every match in the section is kept.
    # :skill_names is also non-scalar: an array of raw skill name strings pulled from the CV's
    # skills section, left unmatched to the platform Skill list here — see ProfileMapper for that.
    class FieldExtractor
      EMAIL_REGEX = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
      STRONG_PHONE_REGEX = /
        (?:\+31[\s-]?6[\s-]?(?:\d{2}[\s-]?){3}\d{2})
        |(?:\+31[\s-]?\(?0?\d{1,3}\)?[\s-]?\d{6,7})
        |(?:\b06[\s-]?(?:\d{2}[\s-]?){3}\d{2}\b)
        |(?:\b0\d{1,3}[\s-]?\d{6,7}\b)
      /x
      # Requires 9+ digits total (not just 9 chars of digits-and-separators) so date ranges like
      # "2015 - 2017" (only 8 digits) don't get mistaken for a phone number.
      LOOSE_PHONE_REGEX = /\+?\d(?:[\s\-()]*\d){8,}/
      BIG_NUMBER_REGEX = /\bBIG[-\s]?(?:nummer|number|registratienummer)?[:\s]*(\d{8,11})\b/i
      LOOSE_BIG_NUMBER_REGEX = /\b\d{11}\b/
      NAME_INFIXES = %w[van de der den ter ten von het 't].freeze
      SUMMARY_HEADINGS = %w[profiel over\ mij profile summary introduction personal\ profile about\ me].freeze
      OTHER_SECTION_HEADINGS = %w[
        contact werkervaring experience opleiding education vaardigheden skills
        talen languages certificaten certificates referenties references
        strengths certification certifications
      ].freeze
      EDUCATION_HEADINGS = %w[opleiding opleidingen education educatie onderwijs].freeze
      WORK_EXPERIENCE_HEADINGS = %w[
        werkervaring werkgeschiedenis experience work\ experience employment employment\ history
        professional\ experience
      ].freeze
      SKILLS_HEADINGS = %w[vaardigheden skills competenties competencies].freeze
      SKILL_SEPARATOR_REGEX = /,|•|·|\|/
      DATE_RANGE_REGEX = /(\d{4})\s*(?:[-–—]|tot|to|until)\s*(\d{4}|present|heden|current|nu)/i
      EDUCATION_LEVEL_PATTERNS = {
        /\bmbo\b/i => :mbo,
        /\bhbo\b/i => :hbo,
        /\bbachelor\b/i => :bachelor,
        /\bb\.?sc\b/i => :bachelor,
        /\bmaster\b/i => :master,
        /\bm\.?sc\b/i => :master,
        /\bph\.?d\b/i => :doctor,
        /\bdoctor(aal)?\b/i => :doctor,
        /\bcursus\b/i => :course,
        /\bcourse\b/i => :course,
        /\bcertificat(e|ion)\b/i => :course
      }.freeze
      INSTITUTION_KEYWORDS = %w[university universiteit college hogeschool school institute institut academy academie].freeze
      # Multi-column CV templates (common in exported resumes) render two columns' worth of content
      # at the same vertical position, so pdf-reader/docx concatenate them onto one "line" separated
      # by a wide run of whitespace. Splitting on that gives each column its own logical line —
      # without it, heading detection and the summary heuristic misread column-merged text.
      COLUMN_SPLIT_REGEX = /\s{3,}/

      def initialize(text)
        @text = text.to_s
        @lines = @text.each_line.flat_map { |line| line.split(COLUMN_SPLIT_REGEX) }.map(&:strip).reject(&:blank?)
      end

      def call
        {}.merge(extract_name)
          .merge(compact_field(:email, extract_email))
          .merge(compact_field(:phone, extract_phone))
          .merge(compact_field(:city, extract_alias_match("city")))
          .merge(compact_field(:country, extract_alias_match("country")))
          .merge(compact_field(:job_function, extract_alias_match("job_function")))
          .merge(compact_field(:big_number, extract_big_number))
          .merge(compact_field(:suggested_summary, extract_summary))
          .merge(compact_field(:education_entries, extract_education_entries))
          .merge(compact_field(:work_experience_entries, extract_work_experience_entries))
          .merge(compact_field(:skill_names, extract_skills))
      end

      private

      attr_reader :text, :lines

      def compact_field(field, extracted_value)
        extracted_value ? { field => extracted_value } : {}
      end

      def extract_email
        matches = text.scan(EMAIL_REGEX).uniq
        return if matches.empty?

        ExtractedValue.new(value: matches.first, confidence: matches.one? ? :high : :low, matched_pattern: EMAIL_REGEX.source)
      end

      def extract_phone
        if (match = text.match(STRONG_PHONE_REGEX))
          ExtractedValue.new(value: match[0].strip, confidence: :high, matched_pattern: "strong_phone_pattern")
        elsif (match = text.match(LOOSE_PHONE_REGEX))
          ExtractedValue.new(value: match[0].strip, confidence: :low, matched_pattern: "loose_phone_pattern")
        end
      end

      def extract_name
        candidate_line = lines.first(5).find { |line| name_like?(line) }
        return {} unless candidate_line

        tokens = candidate_line.split
        confidence = lines.first(2).include?(candidate_line) ? :high : :low

        {
          first_name: ExtractedValue.new(value: tokens.first, confidence: confidence, matched_pattern: "name_heuristic"),
          last_name: ExtractedValue.new(value: tokens[1..].join(" "), confidence: confidence, matched_pattern: "name_heuristic")
        }
      end

      def name_like?(line)
        return false if line.length > 60 || line.match?(/[@\d]/)

        tokens = line.split
        return false unless (2..5).cover?(tokens.size)
        return false unless capitalized_word?(tokens.first) && capitalized_word?(tokens.last)

        tokens[1..-2].all? { |token| capitalized_word?(token) || NAME_INFIXES.include?(token.downcase) }
      end

      def capitalized_word?(token)
        token.match?(/\A\p{Lu}[\p{L}'-]+\z/)
      end

      # Among aliases that match at all, prefer an "exact" match_type over "keyword", and — within
      # the same match_type — whichever pattern appears earliest in the text. A resume mentions many
      # past job titles/cities; the one nearest the top is far more likely to be the current one than
      # whichever pattern happens to be longest.
      def extract_alias_match(field)
        candidates = Onboarding::CvExtractionAlias.for_field(field).filter_map do |a|
          match = text.match(/(?<![\p{L}\p{N}])#{Regexp.escape(a.pattern)}(?![\p{L}\p{N}])/i)
          [ a, match.begin(0) ] if match
        end
        return if candidates.empty?

        best, = candidates.min_by { |(a, position)| [ a.exact? ? 0 : 1, position ] }
        ExtractedValue.new(value: best.value, confidence: best.exact? ? :high : :low, matched_pattern: best.pattern)
      end

      def extract_big_number
        if (match = text.match(BIG_NUMBER_REGEX))
          ExtractedValue.new(value: match[1], confidence: :high, matched_pattern: "big_number_labeled")
        elsif (match = text.match(LOOSE_BIG_NUMBER_REGEX))
          ExtractedValue.new(value: match[0], confidence: :low, matched_pattern: "big_number_bare_digits")
        end
      end

      def extract_summary
        heading_index = lines.index { |line| SUMMARY_HEADINGS.include?(line.downcase.delete(":").strip) }
        return unless heading_index

        after_heading = lines[(heading_index + 1)..].to_a.drop_while { |line| heading_like?(line) }
        body = after_heading.take_while { |line| !heading_like?(line) }.first(5)
        return if body.empty?

        ExtractedValue.new(value: body.join(" "), confidence: :low, matched_pattern: "summary_section_heuristic")
      end

      def heading_like?(line)
        return false if line.length >= 40

        line == line.upcase || line.end_with?(":") || OTHER_SECTION_HEADINGS.include?(line.downcase.delete(":").strip)
      end

      # Best-effort: locates an "Education"/"Opleiding" section, groups its lines into one entry per
      # date range found (or the whole section as a single entry if no dates appear at all), then
      # pulls institution/study/level/dates out of each group. CV layouts vary too much to parse
      # reliably, so every entry is stamped :low confidence and entries with no discernible study
      # text are dropped rather than saved blank.
      def extract_education_entries
        heading_index = lines.index { |line| EDUCATION_HEADINGS.include?(line.downcase.delete(":").strip) }
        return unless heading_index

        body = lines[(heading_index + 1)..].to_a.take_while { |line| !heading_like?(line) }.first(40)
        return if body.empty?

        entries = group_lines_by_date_range(body).filter_map { |group| parse_education_entry(group) }
        return if entries.empty?

        ExtractedValue.new(value: entries, confidence: :low, matched_pattern: "education_section_heuristic")
      end

      # Best-effort, mirrors extract_education_entries: locates a "Werkervaring"/"Experience" section,
      # groups it into one entry per date range, then pulls job_title/company_name/dates/responsibilities
      # out of each group. Supports multiple employers (a CV can list several jobs) — every match found
      # in the section becomes its own entry, not just the first. Entries without a discernible company
      # name are dropped rather than saved blank.
      def extract_work_experience_entries
        heading_index = lines.index { |line| WORK_EXPERIENCE_HEADINGS.include?(line.downcase.delete(":").strip) }
        return unless heading_index

        body = lines[(heading_index + 1)..].to_a.take_while { |line| !heading_like?(line) }.first(60)
        return if body.empty?

        entries = group_lines_by_date_range(body).filter_map { |group| parse_work_experience_entry(group) }
        return if entries.empty?

        ExtractedValue.new(value: entries, confidence: :low, matched_pattern: "work_experience_section_heuristic")
      end

      # Best-effort: locates a "Vaardigheden"/"Skills" section and splits its lines on common list
      # separators (comma, bullet, pipe) into individual skill names. CV skills sections are usually
      # short comma- or bullet-separated lists rather than free prose, so no date-range grouping is
      # needed here unlike education/work experience. Always :low confidence — ProfileMapper matches
      # each name against the platform Skill list itself rather than trusting this as a clean value.
      def extract_skills
        heading_index = lines.index { |line| SKILLS_HEADINGS.include?(line.downcase.delete(":").strip) }
        return unless heading_index

        body = lines[(heading_index + 1)..].to_a.take_while { |line| !heading_like?(line) }.first(20)
        return if body.empty?

        names = body.flat_map { |line| line.split(SKILL_SEPARATOR_REGEX) }
                    .map { |name| clean_text_fragment(name) }
                    .reject(&:blank?)
                    .uniq(&:downcase)
        return if names.empty?

        ExtractedValue.new(value: names, confidence: :low, matched_pattern: "skills_section_heuristic")
      end

      def group_lines_by_date_range(body)
        groups = []

        body.each do |line|
          groups << [] if groups.empty? || line.match?(DATE_RANGE_REGEX)
          groups.last << line
        end

        groups
      end

      def parse_education_entry(group)
        text = group.first(4).join(" ")
        date_match = text.match(DATE_RANGE_REGEX)
        start_date, end_date = parse_date_range(date_match)
        level = education_level_for(text)

        remainder = text.sub(DATE_RANGE_REGEX, "")
        parts = remainder.split(/,| \| | - | at | aan /).map { |part| clean_text_fragment(part) }.reject(&:blank?)
        return if parts.empty?

        institution = parts.find { |part| INSTITUTION_KEYWORDS.any? { |kw| part.downcase.include?(kw) } }
        study = parts.find { |part| part != institution } || parts.first
        return if study.blank?

        { institution: institution, study: study, level: level, start_date: start_date, end_date: end_date }
      end

      def parse_work_experience_entry(group)
        header = group.first
        date_match = header.match(DATE_RANGE_REGEX)
        start_date, end_date = parse_date_range(date_match)
        current_job = date_match ? date_match[2].match?(/present|heden|current|nu/i) : false

        remainder = header.sub(DATE_RANGE_REGEX, "")
        parts = remainder.split(/,| \| | - | at | bij | voor /i).map { |part| clean_text_fragment(part) }.reject(&:blank?)
        return if parts.empty?

        job_title = parts.first
        company_name = parts[1]
        return if company_name.blank?

        responsibilities = group[1..].to_a.map { |line| clean_text_fragment(line) }.reject(&:blank?).join(" ")

        {
          job_title: job_title, company_name: company_name, responsibilities: responsibilities.presence,
          start_date: start_date, end_date: end_date, current_job: current_job
        }
      end

      def clean_text_fragment(text)
        text.to_s.strip.gsub(/\A[-•\s]+|[-•\s]+\z/, "").squeeze(" ")
      end

      def education_level_for(text)
        EDUCATION_LEVEL_PATTERNS.find { |pattern, _| text.match?(pattern) }&.last
      end

      def parse_date_range(match)
        return [ nil, nil ] unless match

        start_date = Date.new(match[1].to_i, 1, 1)
        end_date = Date.new(match[2].to_i, 1, 1) if match[2].match?(/\A\d{4}\z/)
        [ start_date, end_date ]
      rescue ArgumentError
        [ nil, nil ]
      end
    end
  end
end
