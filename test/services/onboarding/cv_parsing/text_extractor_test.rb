require "test_helper"
require "tmpdir"

class Onboarding::CvParsing::TextExtractorTest < ActiveSupport::TestCase
  def extract(content_type:, fixture_name:)
    Onboarding::CvParsing::TextExtractor.new(
      content_type: content_type,
      content: file_fixture(fixture_name).read
    ).call
  end

  test "extracts text from a PDF" do
    text = extract(content_type: "application/pdf", fixture_name: "cvs/michelle_sanders.pdf")

    assert_includes text, "Michelle Sanders"
  end

  test "extracts text from a real two-column resume PDF" do
    text = extract(content_type: "application/pdf", fixture_name: "cvs/paola_smith.pdf")

    assert_includes text, "PAOLA SMITH"
    assert_includes text, "Associate Dentist"
  end

  test "extracts text from a docx" do
    text = extract(
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      fixture_name: "cvs/sample_cv.docx"
    )

    assert_includes text, "Jane van Dijk"
  end

  test "extracts text from a legacy doc via antiword" do
    skip "antiword not installed locally" unless system("which antiword > /dev/null 2>&1")

    text = extract(content_type: "application/msword", fixture_name: "cvs/sample_cv.doc")

    assert_includes text, "Jane van Dijk"
  end

  test "raises for an unsupported content type" do
    assert_raises(Onboarding::CvParsing::TextExtractor::UnsupportedContentTypeError) do
      Onboarding::CvParsing::TextExtractor.new(content_type: "image/png", content: "irrelevant").call
    end
  end

  test "raises when antiword exits with a failure status" do
    Dir.mktmpdir do |bin_dir|
      fake_antiword = File.join(bin_dir, "antiword")
      File.write(fake_antiword, "#!/bin/sh\necho 'corrupt file' 1>&2\nexit 1\n")
      File.chmod(0o755, fake_antiword)

      with_path_prefixed(bin_dir) do
        assert_raises(Onboarding::CvParsing::TextExtractor::AntiwordFailedError) do
          Onboarding::CvParsing::TextExtractor.new(content_type: "application/msword", content: "fake doc bytes").call
        end
      end
    end
  end

  def with_path_prefixed(dir)
    original_path = ENV.fetch("PATH", "")
    ENV["PATH"] = "#{dir}:#{original_path}"
    yield
  ensure
    ENV["PATH"] = original_path
  end
end
