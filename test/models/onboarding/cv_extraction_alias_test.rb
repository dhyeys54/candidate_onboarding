require "test_helper"

class Onboarding::CvExtractionAliasTest < ActiveSupport::TestCase
  test "invalid without field, pattern, or value" do
    alias_record = Onboarding::CvExtractionAlias.new

    assert_not alias_record.valid?
    assert_includes alias_record.errors.attribute_names, :field
    assert_includes alias_record.errors.attribute_names, :pattern
    assert_includes alias_record.errors.attribute_names, :value
  end

  test "invalid with a duplicate pattern for the same field and match_type" do
    Onboarding::CvExtractionAlias.create!(field: "city", pattern: "utrecht", value: "Utrecht", match_type: :exact)
    duplicate = Onboarding::CvExtractionAlias.new(field: "city", pattern: "utrecht", value: "Utrecht", match_type: :exact)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :pattern
  end

  test "valid with the same pattern for a different field" do
    Onboarding::CvExtractionAlias.create!(field: "city", pattern: "utrecht", value: "Utrecht", match_type: :exact)
    other = Onboarding::CvExtractionAlias.new(field: "job_function", pattern: "utrecht", value: "general_dentist", match_type: :exact)

    assert other.valid?
  end

  test "defaults match_type to keyword" do
    alias_record = Onboarding::CvExtractionAlias.new

    assert_predicate alias_record, :keyword?
  end

  test "for_field scopes by field" do
    city = Onboarding::CvExtractionAlias.create!(field: "city", pattern: "utrecht", value: "Utrecht", match_type: :exact)
    country = Onboarding::CvExtractionAlias.create!(field: "country", pattern: "nederland", value: "Netherlands", match_type: :exact)

    assert_includes Onboarding::CvExtractionAlias.for_field("city").to_a, city
    assert_not_includes Onboarding::CvExtractionAlias.for_field("city").to_a, country
  end
end
