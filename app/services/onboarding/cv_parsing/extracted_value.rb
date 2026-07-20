module Onboarding
  module CvParsing
    # One field FieldExtractor pulled out of a CV: the value itself, how sure the extractor was
    # (:high/:low), and what pattern/heuristic matched (kept for Onboarding::CvFieldExtraction's log).
    ExtractedValue = Struct.new(:value, :confidence, :matched_pattern, keyword_init: true)
  end
end
