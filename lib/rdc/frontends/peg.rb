# frozen_string_literal: true
require_relative 'notation'

module Rdc
  module Frontends
    class PegNotation < Notation
      def atom
        if ['&', '!'].include?(value)
          negative = take.value == '!'
          item = atom
          if ['?', '*', '+'].include?(value)
            item = {'t' => {'?' => 'opt', '*' => 'star', '+' => 'plus'}.fetch(take.value), 'item' => item}
          end
          {'t' => 'lookahead', 'negative' => negative, 'item' => item}
        elsif value == '~'
          take
          {'t' => 'note', 'text' => 'cut: do not try later alternatives'}
        else
          super
        end
      end
    end

    # Structural PEG subset. Executable actions are discarded; predicates and cuts stay visible.
    class Peg
      def tool_version = 'peg-parser-v1'

      def parse(text, path: '(PEG grammar)', meta: {})
        entries = []
        text.lines.each_with_index do |line, index|
          line = line.gsub(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|#[^\n]*/) { |part| part.start_with?('#') ? '' : part }
          next if line.strip.empty?
          if (match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)(?:\[[^\]]+\])?\s*(?:<-|:)\s*(.*)$/))
            entries << {'name' => match[1], 'line' => index + 1, 'text' => match[2]}
          else
            raise ArgumentError, "#{path}:#{index + 1}: unsupported PEG declaration" unless entries.any? && line.match?(/^\s/)
            entries.last['text'] += "\n#{line}"
          end
        end
        entries.each do |entry|
          body = entry.delete('text').strip.delete_prefix('|').strip
          tokens = Notation.tokens(body, path: path)
          choice = tokens.any? { |token| token.value == '/' } ? '/' : '|'
          parser = PegNotation.new(tokens, path: path, choice: choice)
          expr = parser.expression
          parser.fail!('unexpected trailing PEG input') if parser.value
          entry['expr'] = {'t' => 'seq', 'items' => [{'t' => 'note', 'text' => 'PEG: alternatives are tried in order'}, expr]}
        end
        NotationGrammar.new(entries, aliases: {}, meta: meta, path: path).result
      end
    end
  end
end
