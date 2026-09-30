# v1.0 implementation record

The original design, roadmap, and work procedures are retained in this directory. This record describes their implemented behavior and deliberate decisions as of 2026-09-30. Phase 6 is a future research backlog; its playground, graph map, per-rule OGP, embedding, and PWA proposals are not v1.0 requirements.

| Scope | Result | Evidence |
|---|---|---|
| Phase 0: presentation and repository hygiene | Responsive, attributed pages; stable rule URLs; canonical/OGP metadata; MIT license; contribution, issue, and PR templates | `lib/rdc/templates/`, `site/`, root documentation |
| Phase 1: reproducible acquisition/build | Eight pinned sources, at least two versions each; preparation commands; hashes; offline IR builds; generated Pages artifacts; legacy redirects | `grammars/{manifest,lock}.yml`, `lib/rdc/{fetcher,generator}.rb`, workflows |
| Phase 2: browsing/accessibility | Native SVG links/history, category TOC/filter, lazy search, themes, scrolling/fit modes, references, paths, internal-rule controls, shortcuts | Browser tests audit all eight current grammars |
| Phase 3: grammar data | Schema-checked IR, conservative simplification, readable/original views, BNF, terminal indexes, preview/export, static JSON API | IR equivalence tests, frontend fixture goldens, renderer golden |
| Phase 4: versions/differences | Two versions per language, adjacent diffs, alternative highlighting, added badges, terminal changes, unified BNF diffs, changelogs, weekly update PR workflow | `lib/rdc/ir/diff.rb`, generated diff pages, `upstream-watch.yml` |
| Phase 5: content | Six Yacc/Bison languages plus Java/Go ANTLR grammars; EBNF/PEG adapters; shortest derivations; categories/examples; English/Japanese; sitemap/robots/JSON-LD | Metadata/examples, source notes, isolated runtime checks |

Additional inexpensive features include a 404 page, print CSS, metrics JSON, and conservative rename suggestions in diff JSON. Phase 6 does not block release.

## Decisions

- Use Lrama as a pinned library to inspect productions, without building parser states. GNU Bison reports handle jq aliases and PostgreSQL compatibility; ANTLR, EBNF, and PEG retain expression trees. See [ADR](adr/0001-ir-source.md).
- Use the existing `railroad_diagrams` library for geometry and Nokogiri for links, annotations, accessibility, and path cleanup. No renderer fork or runtime frontend framework is required.
- Keep raw productions and original diagrams alongside conservative simplification. Epsilon-only actions are removed; nullable rules that also consume input are preserved. Cyclic parameterized expansions are guarded. PEG annotations preserve order/predicate semantics and do not claim CFG equivalence.
- Commit IR, locks, and attributed license copies; generate HTML in CI. Asset names include content hashes. The preview server negotiates gzip, matching static hosting transfer behavior.
- Use native modules with lazy search/preview/export loading. The combined modules fit the 30 KB gzip budget and make no external requests. SVG diagrams are expanded near the viewport, on fragment navigation, for previews/exports, and before printing; their `noscript` sources remain complete native SVGs without JavaScript. Placeholders and per-SVG intrinsic heights reserve layout space.
- Keep metadata fingerprints in IR so changed starts/options/preparation/aliases/categories/licenses cannot silently reuse stale data. Explicit `rdc ir` is required after editing a frontend or preparation script.
- Run Lighthouse directly three times on the largest default grammar rather than introducing a second CI wrapper. HTML validation runs one file per process to bound memory on the complete multilingual site. WCAG checks audit the initial page and then every expanded rule in bounded groups, avoiding quadratic whole-grammar scans. Browser visual baselines store SVG/CSS and compare pixels in the same browser, avoiding OS-specific font snapshots.
- Deploy only artifacts from successful CI for the current `main` SHA. Queue Pages runs so a stale event cannot cancel an eligible deployment; check SHA both before packaging and publishing.

## Validation and operation

Run the commands in [CONTRIBUTING.md](../CONTRIBUTING.md). The build validates every local page/fragment reference and each IR against the schema. Tests cover bounded language equivalence on fixtures and all real productions, source adapters, diff normalization, native navigation, narrow layouts, script-free deep links, storage/theme behavior, search, preview, exports, pixel comparison, and WCAG audits.

The source inventory and Lrama master verification have their own documents. Upstream issues/PRs are separate from the site implementation: no maintainer agreement or merge is claimed. A [local diagram patch and proposal](upstream/README.md) is available for review. The weekly watcher handles stable tagged sources; snapshot-based Java/Go updates require review. Ruby/PHP/Perl examples run with isolated, network-free Docker containers; the other languages' examples are curated and explicitly documented as such.

Screenshots in [screenshots/](screenshots/) show desktop light/dark and a 375px PHP page. Release checks and any environment-dependent results are recorded in the Git history and CI artifacts.
