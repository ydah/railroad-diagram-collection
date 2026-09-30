#!/usr/bin/env ruby
# frozen_string_literal: true
require "stringio"
require "nokogiri"

source = File.expand_path(ARGV.fetch(0, ".cache/lrama"))
$LOAD_PATH.unshift(File.join(source, "lib"))
require "lrama"
text = File.read("test/fixtures/frontends/sample.y")
grammar = Lrama::Parser.new(text, "sample.y").parse
stdlib = Lrama::Parser.new(File.read(Lrama::Command::STDLIB_FILE_PATH), "stdlib.y").parse
grammar.prepend_parameterized_rules(stdlib.parameterized_rules)
grammar.prepare
grammar.validate!
out = StringIO.new
Lrama::Diagram.render(out: out, grammar: grammar)
doc = Nokogiri::HTML5(out.string)
raise "missing document metadata" unless doc.at_css('meta[name="viewport"]') && doc.at_css("meta[charset]") && doc.at_css("html")["lang"] == "en"
raise "invalid CSS" if out.string.include?("stroke: 5;")
ids = doc.css("h2[id]").map { |heading| heading["id"] }
links = doc.css("svg a[href]")
raise "native box links missing" unless links.any? && links.all? { |link| ids.include?(link["href"].delete_prefix("#")) && link.at_css("rect") }
raise "zero paths remain" if doc.css("path").any? { |path| path["d"].match?(/[hv]-?0(?:\.0+)?(?=[A-Za-z\s]|$)/) }
raise "SVG labels missing" unless doc.css("svg").all? { |svg| ids.include?(svg["aria-labelledby"]) }
puts "Patched upstream metadata, native box links, accessible labels, and zero-path checks passed."
