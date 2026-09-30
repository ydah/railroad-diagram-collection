# frozen_string_literal: true
require "minitest/autorun"
require "set"
require "json"
require "yaml"
require_relative "../lib/rdc/ir/schema"
require_relative "../lib/rdc/ir/simplify"
require_relative "../lib/rdc/ir/analysis"
require_relative "../lib/rdc/ir/diff"

class IRTest < Minitest::Test
  def grammar(rules = nil, start: "R", kinds: {}, **rule_keywords)
    rules ||= rule_keywords
    names = rules.keys
    terms = rules.values.flatten.uniq - names
    { "schema" => 1, "language" => "test", "version" => "1", "start" => start,
      "source" => { "repo" => "https://example.org/test", "ref" => "v1", "commit" => "a" * 40,
                    "path" => "test.y", "sha256" => "b" * 64,
                    "license" => { "name" => "MIT", "url" => "https://example.org/license" } },
      "generator" => { "frontend" => "lrama", "tool_version" => "0.8", "rdc" => "1.0" },
      "terminals" => terms.map { |n| { "name" => n, "display" => n, "kind" => "class" } },
      "rules" => rules.map { |n, alts| { "name" => n, "kind" => kinds.fetch(n, "normal"),
                                       "alternatives" => alts.map { |a| { "symbols" => a } } } } }
  end

  def test_schema_rejects_missing_provenance_duplicate_or_undefined_symbols
    ir = grammar("R" => [["x"]])
    assert_same ir, Rdc::IR::Schema.validate!(ir)
    ir["source"].delete("sha256")
    assert_raises(ArgumentError) { Rdc::IR::Schema.validate!(ir) }
    ir = grammar("R" => [["x"]])
    ir["terminals"] << ir["terminals"].first.dup
    assert_raises(ArgumentError) { Rdc::IR::Schema.validate!(ir) }
    ir = grammar("R" => [["x"]])
    ir["rules"][0]["alternatives"][0]["symbols"] << "missing"
    assert_raises(ArgumentError) { Rdc::IR::Schema.validate!(ir) }
    ir["start"] = "missing"
    assert_raises(ArgumentError) { Rdc::IR::Schema.validate!(ir) }
  end

  def test_simplification_preserves_bounded_languages
    cases = [
      [["x"], ["R", ",", "x"]], [[], ["R", "x"]],
      [["x"], ["x", ",", "R"]], [[], ["x", "R"]],
      [["a"], ["b"], ["R", "x"], ["R", "y"]],
      [["a"], ["b"], ["x", "R"], ["y", "R"]],
      [["x"], ["R", "a"], ["b", "R"]],
      [["x"], ["a", "R", "b"]], [["R", "R"], []],
      [[], ["a", "b"], ["a", "c"], ["d", "b"]],
      [["x"], ["R"]], [["R"]]
    ]
    cases.each do |alts|
      ir = grammar("R" => alts)
      expr = Rdc::IR::Simplify.new(ir).rules.fetch("R")
      assert_equal bnf_strings("R", alts, 5), expr_strings(expr, 5, "R", alts), alts.inspect
    end
  end

  def test_lists_are_plus_and_nullable_lists_are_star
    expr = Rdc::IR::Simplify.new(grammar("R" => [["x"], ["R", ",", "x"]])).rules["R"]
    assert_equal "plus", expr["t"]
    assert_equal ",", expr["sep"]["name"]
    expr = Rdc::IR::Simplify.new(grammar("R" => [[], ["x", "R"]])).rules["R"]
    assert_equal "star", expr["t"]
  end

  def test_raw_alternatives_keep_source_order_and_duplicates
    expr = Rdc::IR::Simplify.new(grammar("R" => [["x"], ["y"], ["x"]])).rules(raw: true)["R"]
    assert_equal %w[x y x], expr["items"].map { |e| e["name"] }
  end

  def test_only_proven_epsilon_helpers_are_removed_and_raw_keeps_actions
    ir = grammar({ "R" => [["$@1", "none", "x"], []], "$@1" => [[]], "none" => [[], ["n"]] },
                 kinds: { "$@1" => "midrule" })
    simplified = Rdc::IR::Simplify.new(ir, "epsilon_rules" => ["none"])
    expr = simplified.rules["R"]
    assert_equal "opt", expr["t"]
    assert_equal "none", expr["item"]["items"][0]["name"]
    assert_equal "$@1", simplified.rules(raw: true)["R"]["items"][0]["items"][0]["name"]
  end

  def test_parameterized_expansion_is_shape_based_and_cycles_are_safe
    ir = grammar({ "R" => [["option"]], "option" => [[], ["x"]] }, kinds: { "option" => "parameterized" })
    expr = Rdc::IR::Simplify.new(ir).rules["R"]
    assert_equal Set[[], ["x"]], expr_strings(expr, 4)
    cyclic = grammar({ "R" => [["a"]], "a" => [["b"]], "b" => [["a"], ["x"]] },
                     kinds: { "a" => "parameterized", "b" => "parameterized" })
    assert_equal({ "t" => "nt", "name" => "a" }, Rdc::IR::Simplify.new(cyclic).rules["R"])
  end

  def test_all_rules_preserve_languages_with_parameterized_lists_and_epsilon_helpers
    ir = grammar({ "R" => [["option", "list"]], "option" => [[], ["x"]],
                   "list" => [["item"], ["list", ",", "item"]], "item" => [["z"], ["none", "y"]],
                   "none" => [[]], "$@1" => [[]] },
                 kinds: { "option" => "parameterized", "list" => "parameterized", "$@1" => "midrule" })
    languages = bounded_grammar(ir, 5)
    Rdc::IR::Simplify.new(ir, "epsilon_rules" => ["none"]).rules.each do |name, expr|
      assert_equal languages[name], evaluate(expr, languages, 5), name
    end
  end

  def test_factoring_preserves_partial_shared_prefixes_and_suffixes
    ir = grammar("R" => [["a", "b", "x"], ["a", "c", "x"], ["d", "x"], ["a", "b", "y"]])
    languages = bounded_grammar(ir, 4)
    expr = Rdc::IR::Simplify.new(ir).rules["R"]
    assert_equal languages["R"], evaluate(expr, languages, 4)
  end

  def test_direct_expressions_simplify_but_raw_and_analysis_preserve_bnf_helpers
    ir = grammar({ "R" => [["optional"]], "optional" => [[], ["x"]] }, kinds: { "optional" => "inline" })
    ir["rules"][0]["expr"] = { "t" => "opt", "item" => { "t" => "term", "name" => "x" } }
    assert_same ir, Rdc::IR::Schema.validate!(ir)
    simplify = Rdc::IR::Simplify.new(ir)
    assert_equal "opt", simplify.rules["R"]["t"]
    assert_equal "optional", simplify.rules(raw: true)["R"]["name"]
    assert_equal ["R", "optional"], Rdc::IR::Analysis.new(ir).paths["optional"]
  end

  def test_analysis_handles_nullable_cycles_paths_and_nonproductive_rules
    ir = grammar({ "R" => [["A", "x"], ["B"]], "A" => [["B"]], "B" => [[], ["A"]], "dead" => [["dead"]] })
    analysis = Rdc::IR::Analysis.new(ir)
    assert_equal ["A", "B"], analysis.refs["R"]
    assert_equal ["R", "A"], analysis.used_by["B"]
    assert_equal ["R", "B"], analysis.paths["B"]
    assert_equal ["R"], analysis.terminal_uses["x"]
    assert_equal [], analysis.shortest["R"]
    refute analysis.shortest.key?("dead")
    assert_includes analysis.metrics["unreachable"], "dead"
    assert_includes analysis.metrics["nonproductive"], "dead"
  end

  def test_diff_ignores_action_numbers_but_reports_order_and_alternative_changes
    old = grammar({ "R" => [["x", "@1"], ["y"]], "@1" => [[]], "gone" => [["x"]], "changed" => [["x"]] })
    new = grammar({ "R" => [["y"], ["x", "@2"]], "@2" => [[]], "added" => [["x"]], "changed" => [["z"]] })
    diff = Rdc::IR::Diff.compare(old, new)
    assert_equal ["added"], diff["added"]
    assert_equal ["gone"], diff["removed"]
    assert_equal ["R"], diff["reordered"]
    assert_equal({ "name" => "changed", "added" => [["z"]], "removed" => [["x"]] }, diff["changed"][0])
    assert_equal ["z"], diff["terminals"]["added"]
    assert_equal [{ "from" => "gone", "to" => "added", "score" => 1.0 }], diff["renames"]
  end

  def test_diff_decodes_escaped_names
    assert_empty Rdc::IR::Diff.compare(grammar("R" => [["&gt;"]]), grammar("R" => [[">"]]))["changed"]
  end

  def test_every_committed_rule_preserves_its_projected_bounded_language
    files = Dir[File.expand_path("../data/*/*.json", __dir__)]
    skip "No generated grammars yet" if files.empty?
    files.each do |file|
      ir = JSON.parse(File.read(file, encoding: "UTF-8"))
      meta_file = File.expand_path("../grammars/#{ir['language']}/meta.yml", __dir__)
      meta = File.file?(meta_file) ? YAML.safe_load_file(meta_file) : {}
      meta["simplify"] = meta.fetch("simplify", {}).merge("inline_parameterized" => false, "inline_trivial" => false)
      epsilon = Rdc::IR::Expression.epsilon_only(ir)
      drop = epsilon & (Array(meta["epsilon_rules"]) + ir["rules"].select { |r| r["kind"] == "midrule" }.map { |r| r["name"] })
      names = ir["rules"].map { |rule| rule["name"] }
      simplified = Rdc::IR::Simplify.new(ir, meta).rules
      ir["rules"].each do |rule|
        original = Rdc::IR::Expression.from_rule(rule, names)
        original = Rdc::IR::Expression.map(original) { |e| e["t"] == "nt" && drop.include?(e["name"]) ? { "t" => "eps" } : e }
        # Two symbols bound large real grammars; focused tests above exercise five-symbol derivations.
        languages = Hash.new { |_, name| Set[[name]] }
        languages[rule["name"]] = Set.new
        loop do
          values = evaluate(original, languages, 2)
          break if values == languages[rule["name"]]
          languages[rule["name"]] = values
        end
        assert_equal languages[rule["name"]], evaluate(simplified[rule["name"]], languages, 2), "#{file}: #{rule['name']}"
      end
    end
  end

  private

  def bounded_grammar(ir, k)
    languages = ir["rules"].to_h { |rule| [rule["name"], Set.new] }
    loop do
      changed = false
      ir["rules"].each do |rule|
        values = rule["alternatives"].reduce(Set.new) do |result, alt|
          result | alt["symbols"].reduce(Set[[]]) { |acc, name| concat(acc, languages.fetch(name) { Set[[name]] }, k) }
        end
        next if (values - languages[rule["name"]]).empty?
        languages[rule["name"]] |= values
        changed = true
      end
      break unless changed
    end
    languages
  end

  def evaluate(expr, languages, k)
    case expr["t"]
    when "nt" then languages[expr["name"]]
    when "term" then Set[[expr["name"]]]
    when "eps" then Set[[]]
    when "seq" then expr["items"].reduce(Set[[]]) { |acc, item| concat(acc, evaluate(item, languages, k), k) }
    when "choice" then expr["items"].reduce(Set.new) { |acc, item| acc | evaluate(item, languages, k) }
    when "opt" then evaluate(expr["item"], languages, k) | Set[[]]
    when "star", "plus"
      item = evaluate(expr["item"], languages, k)
      sep = expr["sep"] ? evaluate(expr["sep"], languages, k) : Set[[]]
      acc, frontier = item.dup, item
      loop do
        frontier = concat(concat(frontier, sep, k), item, k) - acc
        break if frontier.empty?
        acc |= frontier
      end
      expr["t"] == "star" ? acc | Set[[]] : acc
    end
  end

  def bnf_strings(name, alts, k)
    out, seen, queue = Set.new, Set.new, [[name]]
    until queue.empty?
      form = queue.shift
      next if seen.include?(form) || form.count { |s| s != name } > k || form.size > 2 * k + 2
      seen << form
      index = form.index(name)
      if index.nil?
        out << form
      else
        alts.each { |alt| queue << form[0...index] + alt + form[(index + 1)..] }
      end
    end
    out
  end

  def concat(a, b, k)
    Set.new(a.to_a.product(b.to_a).map { |left, right| left + right }.select { |s| s.size <= k })
  end

  def expr_strings(expr, k, name = nil, alts = nil)
    case expr["t"]
    when "nt", "term"
      expr["name"] == name ? bnf_strings(name, alts, k) : Set[[expr["name"]]]
    when "eps" then Set[[]]
    when "seq" then expr["items"].reduce(Set[[]]) { |acc, item| concat(acc, expr_strings(item, k, name, alts), k) }
    when "choice" then expr["items"].reduce(Set.new) { |acc, item| acc | expr_strings(item, k, name, alts) }
    when "opt" then expr_strings(expr["item"], k, name, alts) | Set[[]]
    when "star", "plus"
      item = expr_strings(expr["item"], k, name, alts)
      sep = expr["sep"] ? expr_strings(expr["sep"], k, name, alts) : Set[[]]
      acc, frontier = item.dup, item
      loop do
        frontier = concat(concat(frontier, sep, k), item, k) - acc
        break if frontier.empty?
        acc |= frontier
      end
      expr["t"] == "star" ? acc | Set[[]] : acc
    end
  end
end
