require "test_helper"

class Onboarding::RegionTest < ActiveSupport::TestCase
  test "invalid without a name" do
    region = Onboarding::Region.new

    assert_not region.valid?
    assert_includes region.errors.attribute_names, :name
  end

  test "invalid with a duplicate name" do
    region = Onboarding::Region.new(name: "North")

    assert_not region.valid?
    assert_includes region.errors.attribute_names, :name
  end

  test "cannot be destroyed while a candidate_region references it" do
    region = onboarding_regions(:north)

    assert_not region.destroy
    assert_includes region.errors.attribute_names, :base
  end
end
