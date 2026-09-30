# frozen_string_literal: true
require_relative 'notation'

module Rdc
  module Frontends
    class Antlr4
      def tool_version = 'antlr4-parser-v1'

      def parse(text, path: '(ANTLR4 grammar)', meta: {})
        parser = Notation.new(Notation.tokens(text, path: path), path: path)
        entries, aliases = [], {}
        while parser.value
          if ['parser', 'lexer'].include?(parser.value) || parser.value == 'grammar'
            parser.take if ['parser', 'lexer'].include?(parser.value)
            parser.expect('grammar')
            parser.identifier!
            parser.expect(';')
          elsif parser.value == 'mode'
            parser.take
            parser.identifier!
            parser.expect(';')
          elsif ['options', 'tokens', 'channels'].include?(parser.value)
            parser.take
            parser.fail!('expected declaration block') unless parser.value&.start_with?('{')
            parser.take
          elsif parser.value == '@'
            parser.take until parser.value.nil? || parser.value.start_with?('{')
            parser.fail!('unterminated grammar action') unless parser.value
            parser.take
          else
            parser.take if parser.value == 'fragment'
            token = parser.identifier!
            parser.expect(':')
            if token.value.match?(/\A[A-Z]/)
              body = []
              body << parser.take.value until parser.value.nil? || parser.value == ';'
              parser.expect(';')
              body = body.take(body.index('->')) if body.include?('->')
              aliases[token.value] = body.first if body.length == 1 && body.first.start_with?("'")
            else
              expr = parser.expression(';')
              parser.expect(';')
              entries << {'name' => token.value, 'line' => token.line, 'expr' => expr}
            end
          end
        end
        NotationGrammar.new(entries, aliases: aliases, meta: meta, path: path).result
      end
    end
  end
end
