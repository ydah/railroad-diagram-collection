# frozen_string_literal: true
require "minitest/autorun"
require "nokogiri"
require_relative "../lib/rdc/render/svg"

class RenderTest < Minitest::Test
  def setup
    @ir = { "terminals" => [{ "name" => "TOKEN<&", "display" => "<value>&", "kind" => "class" }], "rules" => [] }
    @expr = { "t" => "choice", "items" => [
      { "t" => "seq", "items" => [{ "t" => "term", "name" => "TOKEN<&" }, { "t" => "nt", "name" => "other<&" }] },
      { "t" => "eps" }
    ] }
  end

  def test_svg_links_whole_boxes_escapes_names_constrains_text_and_labels_alternatives
    svg = Rdc::Render::SVG.new(@ir).render(@expr, heading_id: "h-r-rule", alt_classes: ["alt-added", "alt-removed"])
    doc = Nokogiri::XML(svg) { |config| config.strict }
    root = doc.root
    assert_equal "group", root["role"]
    assert_equal "h-r-rule", root["aria-labelledby"]
    link = doc.at_css("a.rr-nt")
    assert_equal "#r-other~3C~26", link["href"]
    assert_equal "Go to rule other<&", link["aria-label"]
    assert link.at_css("rect")
    assert_equal "<value>&", doc.at_css("g.terminal text").text
    assert_equal "TOKEN<&", doc.at_css("g.terminal title").text
    assert_equal "TOKEN<&", doc.at_css("g.terminal")["data-term"]
    doc.css("text").each do |text|
      assert_operator text["textLength"].to_f, :>, 0
      assert_equal "spacingAndGlyphs", text["lengthAdjust"]
    end
    assert_equal 1, doc.css(".alt-added").size
    assert_equal 1, doc.css(".alt-removed").size
    refute_match(/[hv]-?0(?:\.0+)?(?:[A-Za-z ]|$)/, svg)
    assert_equal svg, Rdc::Render::SVG.new(@ir).render(@expr, heading_id: "h-r-rule", alt_classes: ["alt-added", "alt-removed"])
    assert_equal File.read(File.join(__dir__, "fixtures/render.svg")), svg
  end

  def test_raw_render_uses_internal_terminal_names
    doc = Nokogiri::XML(Rdc::Render::SVG.new(@ir, raw: true).render(@expr, heading_id: "heading"))
    assert_equal "TOKEN<&", doc.at_css("g.terminal text").text
  end

  def test_alternative_groups_are_available_without_diff_classes
    doc = Nokogiri::XML(Rdc::Render::SVG.new(@ir).render(@expr, heading_id: "heading"))
    assert_equal 2, doc.css("g.alt").size
    assert_equal %w[0 1], doc.css("g.alt").map { |g| g["data-alt"] }
  end

  def test_every_expression_shape_and_predicate_annotations_renders
    leaf = { "t" => "term", "name" => "TOKEN<&" }
    %w[opt star plus lookahead].each do |type|
      expr = { "t" => type, "item" => leaf, "negative" => true }
      expr["sep"] = leaf if %w[star plus].include?(type)
      svg = Rdc::Render::SVG.new(@ir).render(expr, heading_id: "heading")
      assert Nokogiri::XML(svg) { |c| c.strict }.root
    end
    annotation = Nokogiri::XML(Rdc::Render::SVG.new(@ir).render({ "t" => "note", "text" => "! predicate" }, heading_id: "heading"))
    assert_in_delta 77, annotation.at_css("text")["textLength"].to_f
  end
end
