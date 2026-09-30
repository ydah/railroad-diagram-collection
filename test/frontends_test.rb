# frozen_string_literal: true
require 'minitest/autorun'
require 'json'
require_relative '../lib/rdc/frontends/lrama'
require_relative '../lib/rdc/frontends/bison_report'
require_relative '../lib/rdc/frontends/antlr4'
require_relative '../lib/rdc/frontends/ebnf'
require_relative '../lib/rdc/frontends/peg'

class FrontendsTest < Minitest::Test
  FIXTURES = File.join(__dir__, 'fixtures', 'frontends')

  {'y' => Rdc::Frontends::Lrama, 'output' => Rdc::Frontends::BisonReport,
   'g4' => Rdc::Frontends::Antlr4, 'ebnf' => Rdc::Frontends::Ebnf, 'peg' => Rdc::Frontends::Peg}.each do |extension, frontend|
    define_method("test_#{extension}_golden") do
      path = File.join(FIXTURES, "sample.#{extension}")
      actual = frontend.new.parse(File.read(path, encoding: 'UTF-8'), path: path)
      assert_equal JSON.parse(File.read("#{path}.json", encoding: 'UTF-8')), actual
      names = actual['rules'].map { |rule| rule['name'] } + actual['terminals'].map { |terminal| terminal['name'] }
      actual['rules'].each { |rule| rule['alternatives'].each { |alt| assert_empty alt['symbols'] - names } }
    end
  end

  def test_raw_symbols_and_provenance_are_not_guessed
    ir = Rdc::Frontends::Lrama.new.parse(File.read(File.join(FIXTURES, 'sample.y')), path: 'sample.y')
    assert ir['terminals'].any? { |token| token['name'] == "'\\n'" }
    assert ir['terminals'].any? { |token| token['name'] == "'>'" }
    assert_equal 'class', ir['terminals'].find { |token| token['name'] == 'CLASS' }['display']
    assert_equal 'keyword', ir['terminals'].find { |token| token['name'] == 'CLASS' }['kind']
    option = ir['rules'].find { |rule| rule['name'] == "option_'\\n'" }
    assert_equal({'template' => 'option', 'args' => ["'\\n'"]}, option['origin'])
    assert_equal 'normal', ir['rules'].find { |rule| rule['name'] == 'option_user_named' }['kind']
    assert ir['rules'].any? { |rule| rule['kind'] == 'midrule' }
  end

  def test_unsupported_notation_fails_explicitly
    assert_raises(ArgumentError) { Rdc::Frontends::Antlr4.new.parse('grammar X; start: ~WORD;', path: 'bad.g4') }
    assert_raises(ArgumentError) { Rdc::Frontends::Ebnf.new.parse("start ::= [a-z] - 'x'", path: 'bad.ebnf') }
    assert_raises(ArgumentError) { Rdc::Frontends::Peg.new.parse('@header "code"', path: 'bad.peg') }
  end

  def test_whitespace_literal_has_a_visible_label
    terminal = Rdc::Frontends::Common.terminal("' '")
    assert_equal "' '", terminal['display']
  end

  def test_bison_metadata_preserves_token_identity
    path = File.join(FIXTURES, 'sample.output')
    frontend = Rdc::Frontends::BisonReport.new
    ir = frontend.parse(File.read(path), path: path)
    assert_equal 'bison (GNU Bison) 3.8.2', frontend.tool_version
    terminal = ir['terminals'].find { |token| token['name'] == 'DEFINEDOR' }
    assert_equal '//', terminal['display']
    assert_equal ['list', 'DEFINEDOR'], ir['rules'].find { |rule| rule['name'] == 'start' }['alternatives'].first['symbols']
  end
end
