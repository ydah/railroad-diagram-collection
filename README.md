# Railroad Diagram Collection

[Browse the diagrams](https://ydah.github.io/railroad-diagram-collection/) · [日本語](https://ydah.github.io/railroad-diagram-collection/ja/)

A searchable, bilingual reference for parser grammars, with native rule links, readable and original diagrams, BNF, terminal indexes, examples, and version comparisons. Every grammar records source tags, commits, hashes, and licenses.

| Language | Versions | Source format |
|---|---|---|
| Ruby | 4.0, 3.4 | Lrama / `parse.y` |
| PHP | 8.5, 8.4 | Lrama / `zend_language_parser.y` |
| Perl | 5.44, 5.42 | Lrama / `perly.y` |
| jq | 1.8.2, 1.8.1, 1.7.1 | GNU Bison report |
| PostgreSQL | 18, 17 | GNU Bison report |
| mruby | 4.0, 3.4 | Lrama / `parse.y` |
| Java | September and July 2026 snapshots | ANTLR4 / grammars-v4 |
| Go | June and February 2026 snapshots | ANTLR4 / grammars-v4 |

Java/Go dates identify grammar snapshots, not language releases. Parser productions are not the complete language specification: lexical state, semantic checks, and embedded actions also affect accepted programs. Ruby diagrams describe `parse.y`; the default Prism parser can differ.

## Build and preview

Use Ruby 3.4+, Bundler, and Git. Node.js 24 is needed for browser checks, GNU Bison 3 for regenerating jq/PostgreSQL IR, and Docker for checking examples.

```sh
bundle install
bundle exec exe/rdc build
bundle exec exe/rdc serve --port 8000
```

Open `http://127.0.0.1:8000`. Builds use committed IR without fetching upstream sources. GitHub Actions validates and publishes the generated `dist/` directory to Pages.

To refresh pinned sources and regenerate IR:

```sh
bundle exec exe/rdc fetch
bundle exec exe/rdc ir
bundle exec exe/rdc build
```

Limit `fetch`/`ir` with `ruby` or `php@8.4`; `build --only php` builds both PHP versions. Existing output directories must carry the generated `.rdc-site` marker before replacement.

```sh
bundle exec exe/rdc diff php 8.4 8.5
bundle exec exe/rdc diff ruby 3.4 4.0 --format json
bundle exec exe/rdc check-updates
bundle exec exe/rdc doctor
```

## Data and development

`grammars/manifest.yml` records sources, frontends, preparation commands, and versions; `grammars/lock.yml` pins resolved commits and hashes. `data/<language>/<version>.json` is the IR, validated against [schema/ir-v1.json](schema/ir-v1.json). `lib/rdc/` contains extraction, analysis, simplification, rendering, and site generation. `site/` contains browser assets and translations.

The static API starts at [`/api/v1/index.json`](https://ydah.github.io/railroad-diagram-collection/api/v1/index.json), with IR, search indexes, and metrics. Bison/Yacc, ANTLR4, EBNF, and PEG adapters have fixtures. EBNF/PEG support a documented subset and reject unsupported notation.

Read [CONTRIBUTING.md](CONTRIBUTING.md), [source notes](docs/SOURCES.md), [Lrama master verification](docs/LRAMA_MASTER.md), and the [implementation record](docs/IMPLEMENTATION.md). Python and JavaScript need suitable grammar sources and frontend validation before inclusion; Lrama cannot read arbitrary language specifications.

## License

Site code is [MIT](LICENSE). Grammar data retains upstream licenses; attributed copies are kept in `grammars/<language>/LICENSE.upstream` and published on the licenses page.
