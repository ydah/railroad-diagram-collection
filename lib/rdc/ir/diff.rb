# frozen_string_literal: true
require_relative "normalize"

module Rdc
  module IR
    module Diff
      module_function

      def compare(before, after, epsilon_rules: [])
        old = Normalize.alternatives(before, epsilon_rules: epsilon_rules)
        new = Normalize.alternatives(after, epsilon_rules: epsilon_rules)
        added, removed = (new.keys - old.keys).sort, (old.keys - new.keys).sort
        old_expr = before["rules"].to_h { |r| [Normalize.name(r["name"]), r["expr"] && Normalize.expression(r["expr"])] }
        new_expr = after["rules"].to_h { |r| [Normalize.name(r["name"]), r["expr"] && Normalize.expression(r["expr"])] }
        changed, reordered = [], []
        (old.keys & new.keys).sort.each do |name|
          delta_added, delta_removed = new[name] - old[name], old[name] - new[name]
          if delta_added.any? || delta_removed.any? || old_expr[name] != new_expr[name]
            changed << { "name" => name, "added" => delta_added, "removed" => delta_removed }
          elsif old[name] != new[name]
            reordered << name
          end
        end
        old_terms = before["terminals"].map { |t| Normalize.name(t["name"]) }.reject { |n| Normalize::MIDRULE.match?(n) }
        new_terms = after["terminals"].map { |t| Normalize.name(t["name"]) }.reject { |n| Normalize::MIDRULE.match?(n) }
        {
          "language" => after["language"], "from" => before["version"], "to" => after["version"],
          "added" => added, "removed" => removed, "changed" => changed, "reordered" => reordered,
          "terminals" => { "added" => (new_terms - old_terms).sort, "removed" => (old_terms - new_terms).sort },
          "renames" => rename_candidates(old, new, removed, added)
        }
      end

      def rename_candidates(old, new, removed, added)
        removed.product(added).filter_map do |from, to|
          union = old[from] | new[to]
          next if union.empty?
          score = (old[from] & new[to]).size.fdiv(union.size)
          { "from" => from, "to" => to, "score" => score.round(3) } if score >= 0.8
        end.sort_by { |r| [-r["score"], r["from"], r["to"]] }
      end
    end
  end
end
