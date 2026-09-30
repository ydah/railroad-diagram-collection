# frozen_string_literal: true
module Rdc
  module IR
    module Expression
      module_function

      def sequence(items)
        items = items.flat_map { |e| e["t"] == "seq" ? e["items"] : [e] }.reject { |e| e["t"] == "eps" }
        return { "t" => "eps" } if items.empty?
        return items.first if items.size == 1
        { "t" => "seq", "items" => items }
      end

      def choice(items, optional: true)
        items = items.flat_map { |e| e["t"] == "choice" ? e["items"] : [e] }.uniq
        return { "t" => "eps" } if items.empty?
        return items.first if items.size == 1
        if optional && items.any? { |e| e["t"] == "eps" }
          return { "t" => "opt", "item" => choice(items.reject { |e| e["t"] == "eps" }) }
        end
        { "t" => "choice", "items" => items }
      end

      def symbols(expr)
        case expr["t"]
        when "nt", "term" then [expr["name"]]
        else children(expr).flat_map { |child| symbols(child) }
        end
      end

      def children(expr)
        expr.fetch("items", []) + [expr["item"], expr["sep"]].compact
      end

      def map(expr, &block)
        copy = expr.dup
        copy["items"] = expr["items"].map { |e| map(e, &block) } if expr["items"]
        %w[item sep].each { |key| copy[key] = map(expr[key], &block) if expr[key] }
        block.call(copy)
      end

      def from_rule(rule, rule_names, raw: false)
        return rule["expr"] if rule["expr"] && (!raw || rule.fetch("alternatives").empty?)
        alternatives = rule.fetch("alternatives").map do |alt|
          sequence(alt.fetch("symbols").map do |name|
            { "t" => rule_names.include?(name) ? "nt" : "term", "name" => name }
          end)
        end
        return { "t" => "eps" } if alternatives.empty?
        alternatives.size == 1 ? alternatives.first : { "t" => "choice", "items" => alternatives }
      end

      # A nullable rule can also produce tokens. Only proven epsilon-only rules may disappear.
      def epsilon_only(ir)
        known = []
        loop do
          added = ir.fetch("rules").filter_map do |rule|
            next if known.include?(rule["name"]) || rule["expr"] || rule["alternatives"].empty?
            rule["name"] if rule["alternatives"].all? { |a| (a["symbols"] - known).empty? }
          end
          break if added.empty?
          known.concat(added)
        end
        known
      end
    end
  end
end
