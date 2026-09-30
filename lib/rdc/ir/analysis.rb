# frozen_string_literal: true
require_relative "expression"

module Rdc
  module IR
    class Analysis
      attr_reader :refs, :used_by, :paths, :terminal_uses, :shortest, :metrics

      def initialize(ir)
        @ir = ir
        @rules = ir.fetch("rules").to_h { |r| [r["name"], r] }
        @exprs = @rules.transform_values { |r| Expression.from_rule(r, @rules.keys, raw: true) }
        @refs, @used_by = {}, @rules.to_h { |name, _| [name, []] }
        @terminal_uses = ir["terminals"].to_h { |term| [term["name"], []] }
        @exprs.each do |name, expr|
          symbols = Expression.symbols(expr).uniq
          @refs[name] = symbols & @rules.keys
          @refs[name].each { |target| @used_by[target] << name }
          (symbols & @terminal_uses.keys).each { |term| @terminal_uses[term] << name }
        end
        @paths = paths_from(ir.fetch("start"))
        @shortest = shortest_yields
        @metrics = {
          "rules" => @rules.size, "terminals" => ir["terminals"].size,
          "alternatives" => ir["rules"].sum { |r| r["alternatives"].size },
          "unreachable" => @rules.keys - @paths.keys - ir["rules"].select { |r| r["kind"] == "accept" }.map { |r| r["name"] },
          "nonproductive" => @rules.keys - @shortest.keys,
          "recursive" => @refs.select { |name, targets| targets.include?(name) }.keys,
          "most_used" => @used_by.sort_by { |name, sources| [-sources.size, name] }.first(10).to_h
        }
      end

      private

      def paths_from(start)
        result, queue = { start => [start] }, [start]
        queue.each do |name|
          @refs.fetch(name, []).each do |target|
            next if result.key?(target)
            result[target] = result[name] + [target]
            queue << target
          end
        end
        result
      end

      def shortest_yields
        yields = {}
        loop do
          changed = false
          @exprs.each do |name, expr|
            candidate = shortest_expr(expr, yields)
            next unless candidate && (!yields.key?(name) || candidate.size < yields[name].size)
            yields[name] = candidate
            changed = true
          end
          break unless changed
        end
        yields
      end

      def shortest_expr(expr, yields)
        case expr["t"]
        when "term" then [expr["name"]]
        when "nt" then yields[expr["name"]]
        when "eps", "opt", "star", "lookahead", "note" then []
        when "plus" then shortest_expr(expr["item"], yields)
        when "choice" then expr["items"].filter_map { |e| shortest_expr(e, yields) }.min_by(&:size)
        when "seq"
          parts = expr["items"].map { |e| shortest_expr(e, yields) }
          parts.flatten(1) unless parts.include?(nil)
        end
      end
    end
  end
end
