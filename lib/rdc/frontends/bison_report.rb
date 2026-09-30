# frozen_string_literal: true
require 'json'
require_relative 'common'

module Rdc
  module Frontends
    class BisonReport
      def tool_version = @tool_version || 'report-v1'

      def parse(text, path: '(bison report)', meta: {})
        metadata = text[/^RDC_METADATA (.*)$/, 1]
        metadata = metadata ? JSON.parse(metadata) : {}
        @tool_version = metadata['bison']
        aliases = metadata.fetch('aliases', {})
        section = text.split(/^Grammar\s*$/, 2).last
        raise ArgumentError, "#{path}: Grammar section missing" if section == text
        section = section.split(/^(?:Terminals|Nonterminals|State)\b/, 2).first
        rules, current = {}, nil
        section.lines.each do |line|
          next if line.strip.empty?
          match = line.match(/^\s*(?:\d+\s+)?(?:(\S+)\s*:|(\|))\s*(.*?)\s*$/)
          raise ArgumentError, "#{path}: unsupported report line #{line.strip.inspect}" unless match
          current = match[1] if match[1]
          raise ArgumentError, "#{path}: alternative without rule" unless current
          rhs = match[3].gsub(%r{/\*\s*empty\s*\*/}, '').strip
          rhs = '' if ['ε', '%empty'].include?(rhs)
          symbols = rhs.scan(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\S+/).map { |symbol| aliases.fetch(symbol, symbol) }
          rule = rules[current] ||= {'name' => current, 'kind' => Common.kind(current), 'alternatives' => []}
          rule['alternatives'] << {'symbols' => symbols}
        end
        raise ArgumentError, "#{path}: empty grammar" if rules.empty?
        table = text.split(/^Terminals, with rules where they appear\s*$/, 2).last
        table = table == text ? '' : table.split(/^Nonterminals/, 2).first
        declared = table.scan(/^\s*((?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\S+))\s+\(\d+\)/).flatten.map { |symbol| aliases.fetch(symbol, symbol) }
        terminal_names = declared + rules.values.flat_map { |rule| rule['alternatives'].flat_map { |alt| alt['symbols'] } }.uniq - rules.keys
        start = rules.dig('$accept', 'alternatives', 0, 'symbols', 0) || rules.keys.first
        {'start' => start, 'rules' => rules.values,
         'terminals' => terminal_names.uniq.map { |name| Common.terminal(name, aliases.key(name), meta, internal: ['YYEOF', '$end', 'error'].include?(name)) }}
      end
    end
  end
end
