module Onboarding
  module CvParsing
    # Rule-based (regex/heuristic) extraction of scalar CandidateProfile/User fields from raw CV
    # text. Pure text-in, hash-out — no AR writes here, see ProfileMapper for that. Ambiguous fields
    # (job_function, city, country) are matched against the Onboarding::CvExtractionAlias dictionary
    # rather than hardcoded lists, so the alias table can grow without touching this class.
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
    end
  end
end
