# Grammar sources and attribution

Every generated page and API record identifies its upstream repository, source file, immutable commit, original SHA-256, preprocessed SHA-256, frontend, and license. `grammars/manifest.yml` selects versions, and `grammars/lock.yml` records the resolved commits. Java and Go version labels are dated grammar snapshots, not language release numbers.

| Language | Versions or grammar snapshots | Upstream grammar | Selected license |
| --- | --- | --- | --- |
| Ruby | 4.0, 3.4 | [ruby/ruby: parse.y](https://github.com/ruby/ruby/blob/v4.0.0/parse.y) | BSD-2-Clause; original notices in `BSDL` |
| PHP | 8.5, 8.4 | [php/php-src: Zend/zend_language_parser.y](https://github.com/php/php-src/blob/php-8.5.0/Zend/zend_language_parser.y) | Zend Engine License 2.00; `Zend/LICENSE` |
| Perl | 5.44, 5.42 | [Perl/perl5: perly.y](https://github.com/Perl/perl5/blob/v5.44.0/perly.y) | Artistic License 1.0; `Artistic` and grammar-file copyright notice |
| jq | 1.8.2, 1.8.1, 1.7.1 | [jqlang/jq: src/parser.y](https://github.com/jqlang/jq/blob/jq-1.8.2/src/parser.y) | MIT; `COPYING` |
| PostgreSQL | 18, 17 | [postgres/postgres: src/backend/parser/gram.y](https://github.com/postgres/postgres/blob/REL_18_0/src/backend/parser/gram.y) | PostgreSQL License; `COPYRIGHT` |
| mruby | 4.0, 3.4 | [mruby/mruby: mrbgems/mruby-compiler/core/parse.y](https://github.com/mruby/mruby/blob/4.0.0/mrbgems/mruby-compiler/core/parse.y) | MIT; `LICENSE` and notice in `include/mruby.h` |
| Java | 2026-09, 2026-07 | [grammars-v4: JavaParser.g4 and JavaLexer.g4](https://github.com/antlr/grammars-v4/tree/8c7680c4d28a2c84c8a1077a8b3dad4b37b300df/java/java) | BSD-3-Clause; complete notices in both grammar headers |
| Go | 2026-06, 2026-02 | [grammars-v4: GoParser.g4 and GoLexer.g4](https://github.com/antlr/grammars-v4/tree/5a9a89fa7274878bdb93877c4be5d56859c08e5e/golang) | BSD-3-Clause; complete notices in both grammar headers |

The application code is MIT. This does not relicense upstream grammars, their diagrams, or their IR. The complete selected notices are retained in each `grammars/<language>/LICENSE.upstream` and copied into the generated licenses page. ANTLR preprocessing reads both complete source files, including their notices. Perl's grammar permits either GPL or Artistic licensing; this collection selects Artistic. Ruby permits BSD-2-Clause or its Ruby-specific terms; this collection selects BSD-2-Clause.

PHP's parser belongs to the Zend Engine and explicitly names the Zend Engine License 2.00. Using the repository's PHP License for this file would be inaccurate. Required acknowledgments:

> This product includes the Zend Engine, freely available at http://www.zend.com
>
> The Zend Engine is freely available at http://www.zend.com

Ruby grammar copyright: Yukihiro Matsumoto. PHP grammar authors: Andi Gutmans, Zeev Suraski, and Nikita Popov; copyright Zend Technologies Ltd. Perl grammar copyright: Larry Wall and others. jq copyright: Stephen Dolan. PostgreSQL grammar copyright: PostgreSQL Global Development Group and Regents of the University of California. mruby copyright: mruby developers. Java and Go grammar contributors and their years are preserved verbatim in both upstream header notices.

These are parser grammars. Lexer modes, semantic actions, precedence decisions, and interpreter checks impose additional constraints beyond the diagrammed token sequences. Ruby's diagrams use `parse.y`; Ruby 3.4 and later default to Prism. ANTLR semantic predicates and actions are omitted from the structural diagrams. See [ADR 0001](adr/0001-ir-source.md) for format support and [Lrama master verification](LRAMA_MASTER.md) for the current upstream behavior.

Code examples are curated in `grammars/<language>/examples.yml`. The automated interpreter checks specified by the work procedures cover Ruby 4.0 and 3.4, PHP 8.5 and 8.4, and Perl 5.44 and 5.42:

```sh
bundle exec ruby scripts/check_examples.rb
```

This uses the official `ruby`, `php`, and `perl` Docker images, with Ruby's `--parser=parse.y` option. The official image tags were checked against [docker-library/official-images](https://github.com/docker-library/official-images/tree/master/library). Each compilation runs without network, host mounts, or passed-through environment variables, with capabilities removed, an unprivileged user, a read-only filesystem, memory/CPU/process limits, and a 20-second timeout. A timed-out container is forcibly removed. This isolation matters because `perl -c` can execute `BEGIN` blocks.

The examples for jq, PostgreSQL, mruby, Java, and Go are curated examples; the above script does not claim to compile them. In particular, checking a snippet with Ruby does not establish mruby compatibility. Grammar-derived shortest sequences are illustrative derivations rather than verified executable programs.
