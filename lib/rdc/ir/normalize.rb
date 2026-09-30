# frozen_string_literal: true
require "cgi/escape"
require "json"
require_relative "expression"

module Rdc
  module IR
    module Normalize
      MIDRULE = /\A\$?@\d+\z/
      module_function

      def name(value) = CGI.unescapeHTML(value)

      def alternatives(ir, epsilon_rules: [])
        epsilon = Expression.epsilon_only(ir) & epsilon_rules
        ir.fetch("rules").reject { |rule| MIDRULE.match?(name(rule["name"])) }.to_h do |rule|
          alts = rule.fetch("alternatives").map { |a| symbols(a["symbols"], epsilon) }
          [name(rule["name"]), alts.uniq]
        end
      end

      def symbols(values, epsilon_rules = [])
        values.map { |s| name(s) }.reject { |s| MIDRULE.match?(s) || epsilon_rules.include?(s) }
      end

      def expression(expr)
        Expression.map(expr) do |node|
          node["name"] = name(node["name"]) if node["name"]
          node["items"] = node["items"].uniq.sort_by { |e| JSON.generate(e) } if node["t"] == "choice"
          node
        end
      end
    end
  end
end
