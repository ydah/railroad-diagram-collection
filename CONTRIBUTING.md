# Contributing

Report the language/version, rule URL, expected behavior, and a small example. Link the upstream production when possible.

## Checks

Use Ruby 3.4+, Node.js 24, and Git. GNU Bison 3 is needed for regenerating jq/PostgreSQL (`brew install bison` or `apt-get install bison`); `BISON=/path/to/bison` selects an explicit executable.

```sh
bundle install
npm ci
npx playwright install chromium
bundle exec rake test
bundle exec exe/rdc build
npm test
npm run validate
bundle exec ruby scripts/check_links.rb dist
npm run test:e2e
npm run lighthouse
ruby scripts/check_examples.rb
```

The last command requires Docker. Examples run in isolated containers without repository credentials, networking, or a writable source mount. CI installs Chromium's system dependencies. Lighthouse selects the largest default grammar page and takes three mobile runs, requiring median scores of 90/100/100/100 for performance/accessibility/best-practices/SEO. Browser tests audit eight grammars, compare diagram pixels in both themes, test navigation and exports, and reject external requests.

For intentional visual changes, rebuild, review, then run `bundle exec ruby scripts/update_visual_baseline.rb`. The baseline stores SVG and CSS rather than platform-specific PNGs: Playwright renders current and expected diagrams in the same browser and compares pixels. Review changes to the renderer's `test/fixtures/render.svg` golden separately.

## Update a grammar

1. Add an upstream tag or immutable snapshot to `grammars/manifest.yml`; retain the previous version and exactly one default.
2. Run `bundle exec exe/rdc fetch <language>` and `bundle exec exe/rdc ir <language>`. Commit manifest, lock, and IR together; never hand-edit generated JSON/HTML.
3. Inspect `rdc diff <language> <previous> <next>`, terminal changes, and representative diagrams/BNF against upstream.
4. Run checks, update examples, and describe the source and validation in the PR.

The weekly workflow detects stable releases for tagged sources and opens a PR with a grammar diff. Date-based Java/Go snapshots need deliberate selection. A GitHub App may be configured using `BOT_APP_ID` and `BOT_PRIVATE_KEY`; otherwise the repository token creates the PR and explicitly requests CI for its branch. Enable Actions' permission to create pull requests in repository settings.

## Add a language

`bundle exec exe/rdc new-lang <id>` creates a starter entry. Fill in the source, grammar path, sparse paths, frontend, start rule, version, and verified file-level license. Preparation commands are argument arrays; `{root}` refers to a checked-in script.

Add metadata, examples keyed by real rule names, and an attributed `LICENSE.upstream` copy. Reuse an adapter when possible. New adapters need input fixtures, expected IR, and explicit rejection of unsupported syntax. PEG order, predicates, and cuts remain annotations rather than claiming context-free equivalence.

Compare at least ten productions with upstream, verify counts/references, and run simplification equivalence checks. Add runtime example checks and a browser audit, then update README, source notes, and translations.

## Deployment

Set Pages to GitHub Actions. Successful CI on the current `main` commit supplies the deployment artifact; stale runs cannot overwrite it. Manual Deploy first requests CI. HTML is not committed to `main`.

Legacy `/ruby.html`, `/php.html`, and `/perl.html` redirects preserve fragments with JavaScript. Native rule navigation on current URLs works without scripts.
