require "open3"

module Onboarding
  module CvParsing
    # Extracts raw text from an uploaded CV, dispatching on content type. PDF and .docx use
    # pure-Ruby gems; legacy .doc shells out to the antiword system binary (see README for local
    # install) and is best-effort — a missing/failing binary raises like any other unreadable file,
    # which CvParsingService already turns into a parsing_status: failed + manual-fill fallback.
    class TextExtractor
      class UnsupportedContentTypeError < StandardError; end
      class AntiwordFailedError < StandardError; end

      PDF_TYPE = "application/pdf"
      DOCX_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      DOC_TYPE = "application/msword"

      def initialize(content_type:, content:)
        @content_type = content_type
        @content = content
      end

      def call
        case content_type
        when PDF_TYPE then extract_pdf
        when DOCX_TYPE then extract_docx
        when DOC_TYPE then extract_doc
        else
          raise UnsupportedContentTypeError, "unsupported content type: #{content_type}"
        end
      end

      private

      attr_reader :content_type, :content

      def extract_pdf
        PDF::Reader.new(StringIO.new(content)).pages.map(&:text).join("\n")
      end

      def extract_docx
        Docx::Document.open(StringIO.new(content)).text
      end

      def extract_doc
        Tempfile.create([ "cv", ".doc" ]) do |file|
          file.binmode
          file.write(content)
          file.flush

          stdout, stderr, status = Open3.capture3("antiword", file.path)
          raise AntiwordFailedError, stderr.presence || "antiword exited with status #{status.exitstatus}" unless status.success?

          stdout
        end
      end
    end
  end
end
