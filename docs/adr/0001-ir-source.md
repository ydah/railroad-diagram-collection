# ADR 0001: Extract IR before parser-state construction

Status: accepted.

The site needs raw symbol names, token aliases, alternatives, source lines, and parameterized-rule provenance. HTML diagrams do not retain all of this information, and decoding their labels would make correctness depend on escaping and SVG layout.

Use the Lrama library pinned to commit `c8317b55850bc6cd9033ddfbf816377b73f6c7bc`. The adapter follows `Lrama::Command` through `Parser#parse`, the standard-library merge, `Grammar#prepare`, and `Grammar#validate!`. It does not build LR states or emit C. This path handles Ruby, PHP, Perl, and mruby. Raw names come from `symbol.id.s_value`, never HTML or `inspect`.

Parameterized provenance comes from the actual `Parameterized::Resolver` templates and `Grammar::Binding` generated names. Recursive template calls are followed with a visited set, then matched against `created_lhs_list` after preparation. A name such as `option_user_named` remains a normal rule unless the resolver actually created it. Midrule actions retain their generated rules in raw IR and can be removed only by the separate simplifier.

GNU Bison reports are the fallback for jq (Lrama rejects string aliases in precedence declarations) and PostgreSQL (Lrama rejects legacy `%pure-parser`). Preprocessing invokes GNU Bison 3 or newer, retains the entire Grammar and terminal sections, and adds metadata mapping printed aliases back to declared token identifiers. The adapter records the actual Bison version. Existing Bison `.output` files without metadata also work, using their printed symbol identities. Bison remains a build dependency for these two languages; offline site rendering uses committed IR and does not need it.

ANTLR4 parser grammars are read directly, together with their companion lexer files. Literal token spellings come from simple lexer rules; other lexical tokens remain opaque classes. Actions and labels are removed as specified in the design; semantic predicates are not evaluated. Grouping and postfix operators produce exact BNF helper rules and a native expression tree. Helpers are tagged `inline`, so raw grammar structure remains inspectable. Java and Go use complete, commit-pinned upstream grammars, not abbreviated examples.

W3C EBNF and PEG adapters have small golden fixtures. The EBNF adapter handles productions, choices, grouping, postfix operators, character sets, and code points; subtraction and specification constraints fail explicitly. The PEG adapter handles ordered alternatives, repetition, actions, lookahead, and cuts. Predicates and cuts are retained as expression annotations; its BNF projection represents consuming symbols only and does not implement a PEG recognizer. CPython-specific directives and unsupported operators fail instead of being silently discarded. Neither adapter is advertised as covering every grammar in its format.

A CLI JSON dump from Lrama was considered, but the pinned master has no JSON option. Requiring an upstream change would block the site. HTML extraction remains a migration reader, not the current build source.

Validation:

```sh
bundle exec ruby test/frontends_test.rb
bundle exec ruby scripts/check_lrama_master.rb
bundle exec exe/rdc ir
```

Golden fixtures cover all five complete-IR frontends, raw newline and `>` spellings, nested quoted aliases, midrule classification, actual parameterized provenance, Bison alias identity, and explicit unsupported-syntax errors. The adapter is the only layer coupled to Lrama's private API; a dependency update must regenerate all IR and review the diff.
