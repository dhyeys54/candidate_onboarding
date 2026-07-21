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

  test "extracts a BIG registration status via an exact alias" do
    result = extract("I am BIG registered and actively practicing.\n")

    assert_equal "big_registered", result[:big_registration_status].value
    assert_equal :high, result[:big_registration_status].confidence
  end

  test "does not extract a BIG registration status when none is mentioned" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:big_registration_status)
  end

  test "extracts years of experience from a labeled English phrase" do
    result = extract("8 years of experience in general dentistry.\n")

    assert_equal 8, result[:years_of_experience].value
    assert_equal :high, result[:years_of_experience].confidence
  end

  test "extracts years of experience from a Dutch phrase" do
    result = extract("Meer dan 5 jaar werkervaring als tandarts.\n")

    assert_equal 5, result[:years_of_experience].value
  end

  test "does not extract years of experience when the phrase is absent" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:years_of_experience)
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

  test "extracts one education entry with institution, study, level and dates" do
    text = "Education\n2015 - 2019 Bachelor of Dentistry, University of Amsterdam\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    entry = result[:education_entries].value.first
    assert_equal "University of Amsterdam", entry[:institution]
    assert_equal "Bachelor of Dentistry", entry[:study]
    assert_equal :bachelor, entry[:level]
    assert_equal Date.new(2015, 1, 1), entry[:start_date]
    assert_equal Date.new(2019, 1, 1), entry[:end_date]
    assert_equal :low, result[:education_entries].confidence
  end

  test "extracts multiple education entries from a Dutch section heading" do
    text = "Opleiding\n2010 - 2014 MBO Tandartsassistente, ROC Amsterdam\n2014 - 2018 HBO Mondzorgkunde, Hogeschool Utrecht\n\nWerkervaring\nSome job\n"
    result = extract(text)

    entries = result[:education_entries].value
    assert_equal 2, entries.size
    assert_equal :mbo, entries[0][:level]
    assert_equal :hbo, entries[1][:level]
  end

  test "does not extract education entries when there is no education section" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:education_entries)
  end

  test "extracts one work experience entry with job title, company, dates and responsibilities" do
    text = "Werkervaring\n2019 - 2022 Dentist, Smile Clinic Amsterdam\n" \
           "Treated patients and managed schedules\n\nOpleiding\nSome study\n"
    result = extract(text)

    entry = result[:work_experience_entries].value.first
    assert_equal "Dentist", entry[:job_title]
    assert_equal "Smile Clinic Amsterdam", entry[:company_name]
    assert_equal "Treated patients and managed schedules", entry[:responsibilities]
    assert_equal Date.new(2019, 1, 1), entry[:start_date]
    assert_equal Date.new(2022, 1, 1), entry[:end_date]
    assert_not entry[:current_job]
    assert_equal :low, result[:work_experience_entries].confidence
  end

  test "extracts multiple work experience entries, not just the most recent employer" do
    text = "Werkervaring\n2019 - 2022 Dentist, Smile Clinic Amsterdam\n" \
           "2015 - 2018 Junior Dentist, Tandartspraktijk Utrecht\n\nOpleiding\nSome study\n"
    result = extract(text)

    entries = result[:work_experience_entries].value
    assert_equal 2, entries.size
    assert_equal "Smile Clinic Amsterdam", entries[0][:company_name]
    assert_equal "Tandartspraktijk Utrecht", entries[1][:company_name]
  end

  test "marks a work experience entry with a present-tense end date as the current job" do
    text = "Experience\n2020 - present General Dentist at Dental Clinic Utrecht\n"
    result = extract(text)

    entry = result[:work_experience_entries].value.first
    assert_equal "General Dentist", entry[:job_title]
    assert_equal "Dental Clinic Utrecht", entry[:company_name]
    assert_nil entry[:end_date]
    assert entry[:current_job]
  end

  test "does not extract work experience entries when there is no experience section" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:work_experience_entries)
  end

  test "extracts comma-separated skill names from a labeled section" do
    text = "Skills\nEndodontics, Restorative dentistry, Pediatric dentistry\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    assert_equal [ "Endodontics", "Restorative dentistry", "Pediatric dentistry" ], result[:skill_names].value
    assert_equal :low, result[:skill_names].confidence
  end

  test "extracts skills listed one per line under a Dutch heading" do
    text = "Vaardigheden\nSterilisatie\nPreventie\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    assert_equal [ "Sterilisatie", "Preventie" ], result[:skill_names].value
  end

  test "deduplicates skill names case-insensitively" do
    text = "Skills\nScaling, scaling, Patient education\n"
    result = extract(text)

    assert_equal [ "Scaling", "Patient education" ], result[:skill_names].value
  end

  test "does not extract skills when there is no skills section" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:skill_names)
  end

  test "extracts language names from a labeled section via the alias dictionary" do
    text = "Languages\nEnglish, Nederlands\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    assert_equal [ "Dutch", "English" ], result[:language_names].value.sort
    assert_equal :low, result[:language_names].confidence
  end

  test "extracts languages from a Dutch section heading" do
    text = "Talen\nEngels, Nederlands\n\nContact\nEmail: jane@example.com\n"
    result = extract(text)

    assert_equal [ "Dutch" ], result[:language_names].value.sort
  end

  test "does not extract languages when there is no languages section" do
    result = extract("Contact\nEmail: jane@example.com\n")

    assert_not result.key?(:language_names)
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
