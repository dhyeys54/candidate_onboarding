require "test_helper"

class Onboarding::CvParsing::FieldExtractorTest < ActiveSupport::TestCase
  def extract(text)
    Onboarding::CvParsing::FieldExtractor.new(text).call
  end

  test "extracts a title-case name from the top of the document with high confidence" do
    result = extract("Jane van Dijk\nTandarts\n")

    assert_equal "Jane", result[:first_name].value
    assert_equal "van Dijk", result[:last_name].value
    assert_equal :high, result[:first_name].confidence
  end

  test "extracts an ALL-CAPS name from the top of the document" do
    result = extract("PAOLA SMITH\n\nAssociate Dentist\n")

    assert_equal "PAOLA", result[:first_name].value
    assert_equal "SMITH", result[:last_name].value
  end

  test "does not extract a name when no line looks like one" do
    result = extract("CURRICULUM VITAE OF A VERY LONG HEADING WITH NO NAME\n")

    assert_not result.key?(:first_name)
  end

  test "extracts a single email with high confidence" do
    result = extract("Email: jane.vandijk@example.com\n")

    assert_equal "jane.vandijk@example.com", result[:email].value
    assert_equal :high, result[:email].confidence
  end

  test "flags an ambiguous email with multiple candidates as low confidence" do
    result = extract("Contact personal@gmail.com or work@company.example\n")

    assert_equal :low, result[:email].confidence
  end

  test "does not extract an email when none is present" do
    result = extract("No contact info here.\n")

    assert_not result.key?(:email)
  end

  test "extracts a strong NL phone number with high confidence" do
    result = extract("Telefoon: 06-12345678\n")

    assert_equal "06-12345678", result[:phone].value
    assert_equal :high, result[:phone].confidence
  end

  test "does not mistake a date range for a phone number" do
    result = extract("Lead Dentist 2015 - 2017\n")

    assert_not result.key?(:phone)
  end

  test "falls back to a low-confidence loose phone match for non-NL formats" do
    result = extract("Call me at 1-856-734-7944\n")

    assert_equal "1-856-734-7944", result[:phone].value
    assert_equal :low, result[:phone].confidence
  end

  test "matches job_function against an exact alias with high confidence" do
    result = extract("Ik ben werkzaam als tandarts in Utrecht.\n")

    assert_equal "general_dentist", result[:job_function].value
    assert_equal :high, result[:job_function].confidence
  end

  test "matches job_function against a keyword alias with low confidence" do
    result = extract("Experienced Dentist | Patient Care Specialist\n")

    assert_equal "general_dentist", result[:job_function].value
    assert_equal :low, result[:job_function].confidence
  end

  test "prefers the earliest-appearing keyword match over a later, unrelated one" do
    result = extract("Associate Dentist\n\nPrior role: Dental Assistant at a previous clinic.\n")

    assert_equal "general_dentist", result[:job_function].value
  end

  test "matches known city and country aliases" do
    result = extract("Located in Amsterdam, Netherlands.\n")

    assert_equal "Amsterdam", result[:city].value
    assert_equal "Netherlands", result[:country].value
  end

  test "extracts a labeled BIG number with high confidence" do
    result = extract("BIG-nummer: 12345678901\n")

    assert_equal "12345678901", result[:big_number].value
    assert_equal :high, result[:big_number].confidence
  end

  test "extracts a suggested summary from a labeled section" do
    text = "Profiel\nErvaren tandarts met 8 jaar werkervaring.\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    assert_equal "Ervaren tandarts met 8 jaar werkervaring.", result[:suggested_summary].value
    assert_equal :low, result[:suggested_summary].confidence
  end

  test "still finds the summary heading when a two-column layout merges it with another heading" do
    text = "SUMMARY                    STRENGTHS\nAn experienced dentist with great patient care.\n"
    result = extract(text)

    assert_equal "An experienced dentist with great patient care.", result[:suggested_summary].value
  end

  test "returns an empty hash for text with nothing extractable" do
    assert_equal({}, extract(""))
  end

  test "extracts a plausible set of fields from a real resume PDF" do
    text = Onboarding::CvParsing::TextExtractor.new(
      content_type: "application/pdf",
      content: file_fixture("cvs/michelle_sanders.pdf").read
    ).call

    result = extract(text)

    assert_equal "Michelle", result[:first_name].value
    assert_equal "Sanders", result[:last_name].value
    assert_equal "general_dentist", result[:job_function].value
  end
end
