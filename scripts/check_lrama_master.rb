#!/usr/bin/env ruby
# frozen_string_literal: true
require 'json'
require 'nokogiri'
require 'open3'
require 'stringio'
require_relative '../lib/rdc/frontends/lrama'

ROOT = File.expand_path('..', __dir__)
EXPECTED_REVISION = 'c8317b55850bc6cd9033ddfbf816377b73f6c7bc'
source = Gem.loaded_specs.fetch('lrama').full_gem_path
revision, error, status = Open3.capture3('git', '-C', source, 'rev-parse', 'HEAD')
abort "Cannot identify Lrama checkout: #{error}" unless status.success?
abort "Expected #{EXPECTED_REVISION}, found #{revision.strip}" unless revision.strip == EXPECTED_REVISION
adapter = Rdc::Frontends::Lrama.new
fixture = File.join(ROOT, 'test', 'fixtures', 'frontends', 'sample.y')
grammar = adapter.prepare(File.read(fixture, encoding: 'UTF-8'), path: fixture)
output = StringIO.new
# This renders the upstream template directly; none of the site renderer's fixes are applied.
Lrama::Diagram.render(out: output, grammar: grammar)
html = output.string
doc = Nokogiri::HTML5(html)
terminal_newlines = doc.css('g.terminal text').map(&:text).grep(/n/).select { |text| text.start_with?("'") }
heading = doc.css('h2.diagram-header').map(&:text).find { |name| name.start_with?('option_') }
raise 'newline diagram spelling changed' unless terminal_newlines == ["'\\n'"] && heading == "option_'\\n'"
perl = File.join(ROOT, '.cache', 'src', 'perl', '5.44', 'perly.y')
abort 'Run bundle exec exe/rdc fetch perl@5.44 first' unless File.file?(perl)
perl_ir = adapter.parse(File.read(perl, encoding: 'UTF-8'), path: perl)
raise 'Perl rule count changed' unless perl_ir['rules'].length == 139
help, _, help_status = Open3.capture3('ruby', '-I', File.join(source, 'lib'), File.join(source, 'exe', 'lrama'), '--help')
raise 'Cannot inspect Lrama CLI' unless help_status.success?
result = {
  'revision' => revision.strip, 'version' => Lrama::VERSION,
  'L-01' => {'invalid_stroke' => html.include?('stroke: 5;'), 'viewport' => !doc.at_css('meta[name="viewport"]').nil?,
             'charset' => !doc.at_css('meta[charset]').nil?, 'lang' => doc.at_css('html')['lang'],
             'svg_width_100_percent' => html.match?(/svg\s*\{\s*width:\s*100%/m)},
  'L-02' => {'newline_text' => terminal_newlines.first, 'parameterized_heading' => heading, 'double_escape_fixed' => true},
  'L-03' => {'heading_ids' => doc.css('h2.diagram-header[id]').length, 'svg_links' => doc.css('svg a[href]').length,
             'zero_horizontal_paths' => doc.css('path').count { |path| path['d'].match?(/h0(?:\.0)?\z/) }},
  'L-04' => {'json_cli_option' => help.match?(/--(?:dump-)?json/)},
  'L-05' => {'lhs_comment_fixture' => 'accepted', 'perl_5_44_without_preprocessing' => 'accepted', 'perl_rules' => perl_ir['rules'].length}
}
puts JSON.pretty_generate(result)
