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
      LANGUAGES_HEADINGS = %w[talen languages taalvaardigheden language\ skills].freeze
      YEARS_OF_EXPERIENCE_REGEX = /
        (\d{1,2})\+?\s*(?:years?|jaar|jaren)\s*(?:of\s+)?
        (?:combined\s+|relevant\s+|dental\s+|professional\s+|work\s+|werk\s+)*
        (?:experience|ervaring|werkervaring)
      /ix
      # Optional leading month name/abbreviation on either side handles "Oct 2024 – Jul 2026"-style
      # ranges, not just bare "2019 - 2022" years — common in non-dentist (e.g. software) CV formats.
      DATE_RANGE_REGEX = /(?:[A-Za-z]+\.?\s+)?(\d{4})\s*(?:[-–—]|tot|to|until)\s*(?:[A-Za-z]+\.?\s+)?(\d{4}|present|heden|current|nu)/i
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
          .merge(compact_field(:big_registration_status, extract_alias_match("big_registration_status")))
          .merge(compact_field(:years_of_experience, extract_years_of_experience))
          .merge(compact_field(:suggested_summary, extract_summary))
          .merge(compact_field(:education_entries, extract_education_entries))
          .merge(compact_field(:work_experience_entries, extract_work_experience_entries))
          .merge(compact_field(:skill_names, extract_skills))
          .merge(compact_field(:language_names, extract_language_names))
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

        # Drop middle initials ("M.") entirely rather than folding them into last_name — they were
        # only needed to recognize the line as a name, not to populate the name fields.
        tokens = candidate_line.split.reject { |token| middle_initial?(token) }
        confidence = lines.first(2).include?(candidate_line) ? :high : :low

        {
          first_name: ExtractedValue.new(value: tokens.first, confidence: confidence, matched_pattern: "name_heuristic"),
          last_name: ExtractedValue.new(value: tokens[1..].join(" "), confidence: confidence, matched_pattern: "name_heuristic")
        }
      end

      # A middle initial ("M.") fails capitalized_word? (its trailing period isn't a valid trailing
      # char), which used to reject the whole name line — falling through to the next lines.first(5)
      # candidate and misreading e.g. a job-title line as the name instead.
      def name_like?(line)
        return false if line.length > 60 || line.match?(/[@\d]/)

        tokens = line.split
        return false unless (2..5).cover?(tokens.size)
        return false unless capitalized_word?(tokens.first) && capitalized_word?(tokens.last)

        tokens[1..-2].all? { |token| capitalized_word?(token) || NAME_INFIXES.include?(token.downcase) || middle_initial?(token) }
      end

      def capitalized_word?(token)
        token.match?(/\A\p{Lu}[\p{L}'-]+\z/)
      end

      def middle_initial?(token)
        token.match?(/\A\p{Lu}\.\z/)
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

      def extract_years_of_experience
        return unless (match = text.match(YEARS_OF_EXPERIENCE_REGEX))

        ExtractedValue.new(value: match[1].to_i, confidence: :high, matched_pattern: "years_of_experience_pattern")
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

      # Best-effort: locates a "Talen"/"Languages" section and matches its text against the
      # Onboarding::CvExtractionAlias "language" dictionary, which maps NL/EN language names to the
      # canonical Onboarding::Language name ProfileMapper matches against — unlike extract_skills,
      # which keeps raw text for ProfileMapper to match, languages are a closed small set so
      # canonicalizing here up front sidesteps NL/EN spelling differences entirely.
      def extract_language_names
        heading_index = lines.index { |line| LANGUAGES_HEADINGS.include?(line.downcase.delete(":").strip) }
        return unless heading_index

        body = lines[(heading_index + 1)..].to_a.take_while { |line| !heading_like?(line) }.first(20)
        return if body.empty?

        section_text = body.join(" ")
        names = Onboarding::CvExtractionAlias.for_field("language").filter_map do |a|
          a.value if section_text.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(a.pattern)}(?![\p{L}\p{N}])/i)
        end.uniq
        return if names.empty?

        ExtractedValue.new(value: names, confidence: :low, matched_pattern: "languages_section_heuristic")
      end

      # A date-range line marks where a new entry's header sits, but the header's other lines
      # (company/title) can appear *before* it rather than on it — see parse_work_experience_entry.
      # So a new group's start is walked backward from each date-range line as long as the
      # preceding lines still look like header text, rather than starting the group exactly at the
      # date line. Falls back to a single group when no date range is found anywhere in the section.
      def group_lines_by_date_range(body)
        anchor_indices = body.each_index.select { |i| body[i].match?(DATE_RANGE_REGEX) }
        return [ body ] if anchor_indices.empty?

        block_starts = anchor_indices.each_with_index.map do |anchor_index, i|
          floor = i.zero? ? 0 : anchor_indices[i - 1] + 1
          start_index = anchor_index
          start_index -= 1 while start_index > floor && header_line?(body[start_index - 1])
          start_index
        end

        block_starts.each_with_index.map do |start_index, i|
          end_index = i + 1 < block_starts.size ? block_starts[i + 1] - 1 : body.size - 1
          body[start_index..end_index]
        end
      end

      # Heuristic for "this line is more header text, not a wrapped bullet/description line": short,
      # doesn't start with a bullet marker, and starts with an uppercase letter or digit — wrapped
      # continuation text (a bullet line that word-wrapped onto the next physical line) conventionally
      # starts lowercase since it's mid-sentence, which reliably tells the two apart in practice.
      def header_line?(line)
        line.length < 80 && !line.match?(/\A[●•*\-]/) && line.match?(/\A[\p{Lu}\d]/)
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

      # Two header shapes show up in the wild: a "dentist" single-line shape where the date shares a
      # line with the title/company ("2019 - 2022 Dentist, Smile Clinic Amsterdam"), and a multi-line
      # shape common in software-style resumes where a right-aligned date gets column-split onto its
      # own line, with the job title directly above it and the company above that ("Deqode, Indore" /
      # "Solution Engineer" / "Oct 2024 - Jul 2026"). Distinguish them by whether anything is left on
      # the date line once the date itself is stripped out.
      def parse_work_experience_entry(group)
        date_line_index = group.index { |line| line.match?(DATE_RANGE_REGEX) }

        if date_line_index.nil?
          job_title, company_name = header_title_and_company(group.first)
          responsibilities_from = 1
        else
          date_line = group[date_line_index]
          same_line_remainder = clean_text_fragment(date_line.sub(DATE_RANGE_REGEX, ""))
          responsibilities_from = date_line_index + 1

          if same_line_remainder.present?
            job_title, company_name = header_title_and_company(same_line_remainder)
          elsif date_line_index.positive?
            job_title = clean_text_fragment(group[date_line_index - 1])
            company_name = group[0...(date_line_index - 1)]
              .map { |line| clean_text_fragment(line) }.reject(&:blank?).join(", ").presence
          else
            return
          end
        end
        return if company_name.blank?

        date_match = date_line_index && group[date_line_index].match(DATE_RANGE_REGEX)
        start_date, end_date = parse_date_range(date_match)
        current_job = date_match ? date_match[2].match?(/present|heden|current|nu/i) : false

        responsibilities = group[responsibilities_from..].to_a.map { |line| clean_text_fragment(line) }.reject(&:blank?).join(" ")

        {
          job_title: job_title, company_name: company_name, responsibilities: responsibilities.presence,
          start_date: start_date, end_date: end_date, current_job: current_job
        }
      end

      def header_title_and_company(text)
        parts = text.to_s.split(/,| \| | - | at | bij | voor /i).map { |part| clean_text_fragment(part) }.reject(&:blank?)
        [ parts.first, parts[1] ]
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
