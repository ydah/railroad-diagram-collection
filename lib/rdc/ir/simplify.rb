# frozen_string_literal: true
require_relative "expression"

module Rdc
  module IR
    class Simplify
      def initialize(ir, meta = {})
        @ir, @meta = ir, meta
        @rule_names = ir.fetch("rules").map { |r| r["name"] }
        @settings = meta.fetch("simplify", {})
      end

      def rules(raw: false)
        exprs = @ir.fetch("rules").to_h { |r| [r["name"], Expression.from_rule(r, @rule_names, raw: raw)] }
        return exprs if raw
        epsilon = Expression.epsilon_only(@ir)
        removable = []
        if enabled?("drop_midrule")
          removable.concat(@ir["rules"].filter_map { |r| r["name"] if r["kind"] == "midrule" })
        end
        removable.concat(@meta.fetch("epsilon_rules", [])) if enabled?("epsilon")
        removable &= epsilon
        exprs.transform_values!.with_index do |expr, index|
          expr = Expression.map(expr) { |e| e["t"] == "nt" && removable.include?(e["name"]) ? { "t" => "eps" } : e }
          expr = compact(expr, optional: false)
          expr = recursion(@rule_names[index], expr)
          compact(expr, optional: enabled?("epsilon"))
        end
        exprs = inline(exprs) if enabled?("inline_parameterized") || enabled?("inline_trivial", false)
        exprs.transform_values { |e| factor(e) }
      end

      private

      def enabled?(name, default = true) = @settings.fetch(name, default)

      def compact(expr, optional: true)
        Expression.map(expr) do |e|
          case e["t"]
          when "seq" then Expression.sequence(e["items"])
          when "choice" then Expression.choice(e["items"], optional: optional)
          else e
          end
        end
      end

      def items(expr) = expr["t"] == "seq" ? expr["items"] : (expr["t"] == "eps" ? [] : [expr])
      def self_ref?(expr, name) = expr == { "t" => "nt", "name" => name }

      def recursion(name, expr)
        alts = (expr["t"] == "choice" ? expr["items"] : [expr]).map { |a| items(a) }
        recursive, base = alts.partition { |alt| alt.any? { |e| Expression.symbols(e).include?(name) } }
        return expr if recursive.empty? || base.empty?
        # Interior, repeated and mixed left/right recursion retain the original alternatives.
        return expr unless recursive.all? { |a| a.sum { |e| Expression.symbols(e).count(name) } == 1 }
        left = recursive.all? { |a| self_ref?(a.first, name) }
        right = recursive.all? { |a| self_ref?(a.last, name) }
        direction = left && enabled?("left_recursion") ? :left : (right && enabled?("right_recursion") ? :right : nil)
        return expr unless direction
        tails = recursive.map { |a| direction == :left ? a.drop(1) : a[0...-1] }.reject(&:empty?)
        return Expression.choice(base.map { |a| Expression.sequence(a) }) if tails.empty?
        alpha = Expression.choice(base.map { |a| Expression.sequence(a) })
        beta = Expression.choice(tails.map { |a| Expression.sequence(a) })
        return { "t" => "star", "item" => beta } if alpha["t"] == "eps"
        if base.size == 1 && tails.size == 1 && !base[0].empty?
          a, tail = base[0], tails[0]
          matches = direction == :left ? tail.last(a.size) == a : tail.first(a.size) == a
          if matches
            sep = direction == :left ? tail[0...-a.size] : tail.drop(a.size)
            result = { "t" => "plus", "item" => alpha }
            result["sep"] = Expression.sequence(sep) unless sep.empty?
            return result
          end
        end
        loop_expr = { "t" => "star", "item" => beta }
        Expression.sequence(direction == :left ? [alpha, loop_expr] : [loop_expr, alpha])
      end

      def inline(exprs)
        candidates = @ir["rules"].filter_map do |rule|
          expr = exprs.fetch(rule["name"])
          parameterized = rule["kind"] == "parameterized" && enabled?("inline_parameterized")
          trivial = %w[nt term].include?(expr["t"]) && enabled?("inline_trivial", false)
          rule["name"] if parameterized || trivial
        end
        graph = candidates.to_h { |name| [name, Expression.symbols(exprs[name]) & candidates] }
        cyclic = candidates.select do |name|
          queue, seen = graph[name].dup, []
          until queue.empty?
            node = queue.shift
            break true if node == name
            next if seen.include?(node)
            seen << node
            queue.concat(graph.fetch(node, []))
          end
        end
        candidates -= cyclic
        expand = lambda do |expr, stack|
          Expression.map(expr) do |e|
            if e["t"] == "nt" && candidates.include?(e["name"]) && !stack.include?(e["name"])
              expand.call(exprs[e["name"]], stack + [e["name"]])
            else
              e
            end
          end
        end
        exprs.transform_values { |expr| compact(expand.call(expr, [])) }
      end

      def factor(expr)
        Expression.map(expr) do |e|
          next e unless e["t"] == "choice"
          result = e
          result = factor_edge(result, :first) if enabled?("factor_prefix")
          result = factor_edge(result, :last) if enabled?("factor_suffix")
          result
        end
      end

      def factor_edge(expr, edge)
        return expr unless expr["t"] == "choice"
        alts = expr["items"].map { |e| items(e) }
        groups = alts.group_by { |a| a.public_send(edge) }
        return expr unless groups.any? { |key, group| key && group.size > 1 }
        Expression.choice(groups.flat_map do |key, group|
          next group.map { |a| Expression.sequence(a) } unless key && group.size > 1
          rest = group.map { |a| Expression.sequence(edge == :first ? a.drop(1) : a[0...-1]) }
          middle = factor(Expression.choice(rest))
          [Expression.sequence(edge == :first ? [key, middle] : [middle, key])]
        end)
      end
    end
  end
end
