# frozen_string_literal: true
require "json"
require "json_schemer"
require_relative "expression"

module Rdc
  module IR
    module Schema
      PATH = File.expand_path("../../../schema/ir-v1.json", __dir__)
      module_function

      def validate!(ir)
        errors = schemer.validate(ir).map { |e| "#{e['data_pointer']}: #{e['error']}" }
        raise ArgumentError, "Invalid IR: #{errors.first(5).join('; ')}" unless errors.empty?
        names = (ir["rules"] + ir["terminals"]).map { |symbol| symbol["name"] }
        duplicates = names.tally.select { |_, count| count > 1 }.keys
        raise ArgumentError, "Duplicate IR symbols: #{duplicates.join(', ')}" unless duplicates.empty?
        rule_names = ir["rules"].map { |rule| rule["name"] }
        raise ArgumentError, "Unknown start rule: #{ir['start']}" unless rule_names.include?(ir["start"])
        terminal_names = ir["terminals"].map { |term| term["name"] }
        ir["rules"].each do |rule|
          symbols = rule["alternatives"].flat_map { |alt| alt["symbols"] }
          missing = symbols - names
          raise ArgumentError, "#{rule['name']}: undefined symbols #{missing.join(', ')}" unless missing.empty?
          next unless rule["expr"]
          Expression.map(rule["expr"]) do |expr|
            allowed = expr["t"] == "nt" ? rule_names : terminal_names
            if %w[nt term].include?(expr["t"]) && !allowed.include?(expr["name"])
              raise ArgumentError, "#{rule['name']}: invalid #{expr['t']} reference #{expr['name']}"
            end
            expr
          end
        end
        ir
      end

      def schemer
        @schemer ||= JSONSchemer.schema(JSON.parse(File.read(PATH, encoding: "UTF-8")))
      end
    end
  end
end
