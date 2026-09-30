# frozen_string_literal: true
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/rdc/manifest"
require_relative "../lib/rdc/slug"

class ManifestTest < Minitest::Test
  def test_slugs_are_reversible_and_collision_free
    assert_equal "r-~24~401", Rdc::Slug.rule("$@1")
    assert_equal "r-option_~27~5Cn~27", Rdc::Slug.rule("option_'\\n'")
    assert_equal "r-~E3~81~82", Rdc::Slug.rule("あ")
    assert_equal "r-~7E24", Rdc::Slug.rule("~24")
  end

  def test_manifest_rejects_unsafe_version_paths_and_missing_defaults
    base = { "schema" => 1, "languages" => { "example" => {
      "name" => "Example", "frontend" => "lrama", "repo" => "https://example.org/grammar.git",
      "grammar" => "parse.y", "license" => { "name" => "MIT", "url" => "https://example.org/license", "path" => "LICENSE" },
      "versions" => [{ "id" => "../escape", "ref" => "v1", "default" => true }]
    } } }
    Dir.mktmpdir do |directory|
      file = File.join(directory, "manifest.yml")
      File.write(file, YAML.dump(base))
      assert_raises(ArgumentError) { Rdc::Manifest.load(file) }
      base["languages"]["example"]["versions"] = [{ "id" => "1.0", "ref" => "v1" }]
      File.write(file, YAML.dump(base))
      assert_raises(ArgumentError) { Rdc::Manifest.load(file) }
      base["languages"]["example"]["versions"][0]["default"] = true
      File.write(file, YAML.dump(base))
      manifest = Rdc::Manifest.load(file)
      assert_equal 1, manifest.each_version("example@1.0").to_a.size
      assert_raises(ArgumentError) { manifest.each_version("missing").to_a }
    end
  end
end
