import test from "node:test";
import assert from "node:assert/strict";
import { normalize, matchScore, rankSearch } from "../site/assets/js/match.js";

test("search matches aliases, tokens and fuzzy rule names in rank order", () => {
  assert.equal(normalize("Top-Stmt_LIST "), "topstmtlist");
  assert.equal(matchScore("expr", "expr"), 100);
  assert.equal(matchScore("expr", "expression"), 80);
  assert.equal(matchScore("expr", "primary_expr"), 60);
  assert.ok(matchScore("exr", "expression") > 0);
  assert.equal(matchScore("zxq", "expression"), 0);
  assert.deepEqual(rankSearch([
    { n: "expression" }, { n: "primary_expr" }, { n: "expr" }, { n: "other", a: "expr" },
  ], "expr").map((entry) => entry.n), ["expr", "other", "expression", "primary_expr"]);
  assert.equal(rankSearch([{ n: "class_statement", t: ["class"] }], "class")[0].n, "class_statement");
  assert.equal(rankSearch(Array.from({ length: 25 }, (_, i) => ({ n: `expr_${i}` })), "expr").length, 20);
  assert.deepEqual(rankSearch([{ n: "expr" }], " "), []);
});
