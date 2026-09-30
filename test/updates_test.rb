# frozen_string_literal: true
require "minitest/autorun"
require_relative "../lib/rdc/updates"

class UpdatesTest < Minitest::Test
  def test_numeric_sort_and_stable_tags
    language = Rdc::Language.new(tag_pattern: '^v(5)\.(\d*[02468])\.0$')
    assert_equal [[5, 44], "v5.44.0"], Rdc::Updates.latest(%w[v5.9.0 v5.42.0 v5.44.0 v5.45.0 v5.44.0-RC1], language)
    language.tag_pattern = '^v(\d+)\.(\d+)\.0$'
    assert_equal [[4, 10], "v4.10.0"], Rdc::Updates.latest(%w[v4.9.0 v4.10.0 v4.11.0-rc1], language)
  end
end
