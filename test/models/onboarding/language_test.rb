require "test_helper"

class Onboarding::LanguageTest < ActiveSupport::TestCase
  test "invalid without a name" do
    language = Onboarding::Language.new

    assert_not language.valid?
    assert_includes language.errors.attribute_names, :name
  end

  test "invalid with a duplicate name" do
    language = Onboarding::Language.new(name: onboarding_languages(:english).name)

    assert_not language.valid?
    assert_includes language.errors.attribute_names, :name
  end
end
