# frozen_string_literal: true
require 'strscan'
require_relative 'common'

module Rdc
  module Frontends
    # Tokenize grammar notation, never grammar actions. Unknown syntax stays visible as an error.
    class Notation
      Token = Struct.new(:value, :line)
      def self.tokens(text, path:)
        scanner = StringScanner.new(text)
        result = []
        until scanner.eos?
          next if scanner.scan(/\s+|\/\/[^\n]*|\/\*.*?\*\//m)
          line = text[0...scanner.pos].count("\n") + 1
          token = scanner.scan(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\[(?:\\.|[^\]\\])*\]|#x[0-9A-Fa-f]+|[A-Za-z_$][A-Za-z0-9_$]*|\+=|::=|<-|->|[():;|?*+.@#=<>!&~{},\/]/m)
          raise ArgumentError, "#{path}:#{line}: unsupported syntax #{scanner.peek(30).inspect}" unless token
          if token == '{'
            depth = 1
            until depth.zero?
              part = scanner.scan(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*.*?\*\//m) || scanner.getch
              raise ArgumentError, "#{path}:#{line}: unterminated action" unless part
              depth += 1 if part == '{'
              depth -= 1 if part == '}'
              token += part
            end
          end
          result << Token.new(token, line)
        end
        result
      end

      def initialize(tokens, path:, choice: '|')
        @tokens, @path, @choice, @index = tokens, path, choice, 0
      end

      def expression(terminator = nil)
        alternatives = [sequence(terminator)]
        while value == @choice
          take
          alternatives << sequence(terminator)
        end
        alternatives.length == 1 ? alternatives.first : {'t' => 'choice', 'items' => alternatives}
      end

      def sequence(terminator)
        items = []
        while value && value != terminator && value != @choice
          if value.start_with?('{')
            take
            take if value == '?'
            next
          end
          if value == '#'
            take
            identifier!
            next
          end
          if value == '<'
            take
            option = []
            option << take.value until value == '>' || value.nil?
            expect('>')
            fail!('unsupported alternative option') unless option.join.match?(/\Aassoc=(?:left|right)\z/)
            next
          end
          if @tokens[@index + 1]&.value&.match?(/\A(?:=|\+=)\z/)
            identifier!
            take
          end
          item = atom
          if ['?', '*', '+'].include?(value)
            item = {'t' => {'?' => 'opt', '*' => 'star', '+' => 'plus'}.fetch(take.value), 'item' => item}
            take if value == '?' # nongreedy recognition changes priority, not the drawn token language
          end
          items << item
        end
        return {'t' => 'eps'} if items.empty?
        items.length == 1 ? items.first : {'t' => 'seq', 'items' => items}
      end

      def atom
        token = take || fail!('expected expression')
        if token.value == '('
          expression(')').tap { expect(')') }
        elsif token.value.match?(/\A(?:[A-Za-z_$][A-Za-z0-9_$]*|'.*'|".*"|\[.*\]|#x[0-9A-Fa-f]+)\z/m)
          {'t' => 'symbol', 'name' => token.value}
        else
          fail!("unsupported expression token #{token.value.inspect}")
        end
      end

      def value = @tokens[@index]&.value
      def take = @tokens[@index].tap { @index += 1 }
      def expect(expected) = (value == expected ? take : fail!("expected #{expected.inspect}, found #{value.inspect}"))
      def identifier! = (value&.match?(/\A[A-Za-z_$][A-Za-z0-9_$]*\z/) ? take : fail!('expected identifier'))
      def fail!(message) = raise(ArgumentError, "#{@path}:#{@tokens[@index]&.line || @tokens.last&.line}: #{message}")
    end

    # Expand groups/postfix operators into exact BNF. Keep the expression as well for direct drawing.
    class NotationGrammar
      def initialize(entries, aliases:, meta:, path:)
        @entries, @aliases, @meta, @path, @helpers = entries, aliases, meta, path, []
        @rule_names = entries.map { |entry| entry.fetch('name') }
        raise ArgumentError, "#{path}: duplicate rules" unless @rule_names.uniq == @rule_names
        @terminals = {}
      end

      def result
        raise ArgumentError, "#{@path}: empty grammar" if @entries.empty?
        rules = @entries.map do |entry|
          @parent, @counter = entry.fetch('name'), 0
          expr = classify(entry.fetch('expr'))
          {'name' => @parent, 'kind' => 'normal', 'line' => entry.fetch('line'), 'expr' => expr,
           'alternatives' => alternatives(expr)}
        end
        {'start' => @rule_names.first, 'rules' => rules + @helpers, 'terminals' => @terminals.values}
      end

      private

      def classify(expr)
        if expr['t'] == 'symbol'
          name = expr.fetch('name')
          return {'t' => 'nt', 'name' => name} if @rule_names.include?(name)
          @terminals[name] ||= Common.terminal(name, @aliases[name], @meta, internal: name == 'EOF')
          {'t' => 'term', 'name' => name}
        elsif expr['items']
          expr.merge('items' => expr.fetch('items').map { |item| classify(item) })
        elsif expr['item']
          expr.merge('item' => classify(expr.fetch('item')))
        else
          expr
        end
      end

      def alternatives(expr)
        items = expr['t'] == 'choice' ? expr.fetch('items') : [expr]
        items.map { |item| {'symbols' => sequence(item)} }
      end

      def sequence(expr)
        return [] if expr['t'] == 'eps'
        return [expr.fetch('name')] if ['nt', 'term'].include?(expr['t'])
        return expr.fetch('items').flat_map { |item| item['t'] == 'seq' ? sequence(item) : symbol(item) } if expr['t'] == 'seq'
        symbol(expr)
      end

      def symbol(expr)
        return sequence(expr) if ['nt', 'term', 'eps'].include?(expr['t'])
        @counter += 1
        name = "#{@parent}__#{@counter}"
        raise ArgumentError, "#{@path}: helper collision #{name}" if @rule_names.include?(name)
        helper = {'name' => name, 'kind' => 'inline', 'alternatives' => [], 'expr' => expr}
        @helpers << helper
        alts = case expr.fetch('t')
        when 'lookahead', 'note' then [{'symbols' => []}]
        when 'opt' then [{'symbols' => []}] + alternatives(expr.fetch('item'))
        when 'star' then [{'symbols' => []}] + alternatives(expr.fetch('item')).map { |alt| {'symbols' => alt['symbols'] + [name]} }
        when 'plus'
          base = alternatives(expr.fetch('item'))
          base + base.map { |alt| {'symbols' => alt['symbols'] + [name]} }
        else alternatives(expr)
        end
        helper['alternatives'] = alts
        [name]
      end
    end
  end
end
