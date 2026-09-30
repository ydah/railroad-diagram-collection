# frozen_string_literal: true
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/rdc/site/validator"

class SiteTest < Minitest::Test
  def test_validator_checks_local_files_and_anchors_across_pages
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "index.html"), '<main id="main"><a href="#main">Content</a><a href="other.html#target">Other</a></main>')
      other = File.join(directory, "other.html")
      File.write(other, '<main id="target"><a href="#target">Here</a></main>')
      assert Rdc::Site::Validator.check!(directory)
      File.write(other, '<main id="gone"></main>')
      assert_raises(RuntimeError) { Rdc::Site::Validator.check!(directory) }
      File.write(other, '<main id="target"><p id="target">duplicate</p></main>')
      assert_raises(RuntimeError) { Rdc::Site::Validator.check!(directory) }
    end
  end
end
