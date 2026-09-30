# frozen_string_literal: true
require 'lrama'
require_relative 'common'

module Rdc
  module Frontends
    class Lrama
      def tool_version = ::Lrama::VERSION

      def parse(text, path:, meta: {})
        grammar = prepare(text, path: path)
        rules = grammar.rules.group_by { |rule| rule.lhs.id.s_value }.map do |name, alternatives|
          rule = {'name' => name, 'kind' => Common.kind(name),
                  'line' => alternatives.filter_map(&:lineno).min || 1,
                  'alternatives' => alternatives.map { |alt| {'symbols' => alt.rhs.map { |sym| sym.id.s_value }} }}
          if @origins.key?(name) && grammar.parameterized_resolver.created_lhs(name)
            rule.merge!('kind' => 'parameterized', 'origin' => @origins.fetch(name))
          end
          rule
        end
        terminals = grammar.terms.map do |symbol|
          Common.terminal(symbol.id.s_value, symbol.alias_name, meta,
                          internal: symbol.eof_symbol? || symbol.error_symbol? || symbol.undef_symbol?)
        end
        start = rules.find { |rule| rule['kind'] == 'accept' }.fetch('alternatives').first.fetch('symbols').first
        {'start' => start, 'rules' => rules, 'terminals' => terminals}
      end

      # Same parse/stdlib/prepare path as Lrama::Command, without constructing LR states or C output.
      def prepare(text, path:)
        grammar = ::Lrama::Parser.new(text, path).parse
        unless grammar.no_stdlib
          stdlib_path = File.join(::Lrama::Command::LRAMA_LIB, 'grammar', 'stdlib.y')
          stdlib = ::Lrama::Parser.new(File.read(stdlib_path, encoding: 'UTF-8'), stdlib_path).parse
          grammar.prepend_parameterized_rules(stdlib.parameterized_rules)
        end
        @origins = {}
        grammar.rule_builders.each { |builder| builder.rhs.each { |token| record_origin(token, grammar.parameterized_resolver) } }
        grammar.prepare
        grammar.validate!
        grammar
      end

      private

      # Use actual resolver templates and Binding's exact generated names; rule-name prefixes prove nothing.
      def record_origin(token, resolver)
        return unless token.is_a?(::Lrama::Lexer::Token::InstantiateRule)
        template = resolver.find_rule(token)
        bindings = ::Lrama::Grammar::Binding.new(template.parameters, token.args)
        name = bindings.concatenated_args_str(token)
        return if @origins.key?(name)
        @origins[name] = {'template' => template.name, 'args' => token.args.map(&:s_value)}
        token.args.each { |arg| record_origin(arg, resolver) }
        template.rhs.each { |rhs| rhs.symbols.each { |sym| record_origin(bindings.resolve_symbol(sym), resolver) } }
      end
    end
  end
end
