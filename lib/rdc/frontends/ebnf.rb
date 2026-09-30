# frozen_string_literal: true
require_relative 'notation'

module Rdc
  module Frontends
    class Ebnf
      def tool_version = 'w3c-ebnf-parser-v1'

      def parse(text, path: '(W3C EBNF)', meta: {})
        entries = []
        text.lines.each_with_index do |line, index|
          next if line.strip.empty?
          if (match = line.match(/^\s*(?:\[\d+\]\s*)?([A-Za-z_][A-Za-z0-9_]*)\s*::=\s*(.*)$/))
            entries << {'name' => match[1], 'line' => index + 1, 'text' => match[2]}
          else
            raise ArgumentError, "#{path}:#{index + 1}: expected EBNF production" if entries.empty?
            entries.last['text'] += "\n#{line}"
          end
        end
        entries.each do |entry|
          raise ArgumentError, "#{path}: unsupported specification constraint" if entry['text'].match?(/\[(?:VC|WFC):/)
          parser = Notation.new(Notation.tokens(entry.delete('text'), path: path), path: path)
          entry['expr'] = parser.expression
          parser.fail!('unexpected trailing EBNF input') if parser.value
        end
        NotationGrammar.new(entries, aliases: {}, meta: meta, path: path).result
      end
    end
  end
end
