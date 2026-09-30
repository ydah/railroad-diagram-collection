# Lrama master verification

Verified the GitHub `master` head on 2026-09-30: [`c8317b55850bc6cd9033ddfbf816377b73f6c7bc`](https://github.com/ruby/lrama/commit/c8317b55850bc6cd9033ddfbf816377b73f6c7bc). Its gem version remains `0.8.0`, so the version string alone cannot distinguish this source from the released gem. `Gemfile` and `Gemfile.lock` pin the commit.

| Roadmap item | Result on this master | Evidence |
| --- | --- | --- |
| L-01: CSS and mobile document metadata | Still present | Upstream output contains `stroke: 5`, `svg { width: 100% }`, and no viewport, charset, or HTML language attribute. |
| L-02: newline double escaping | Fixed upstream | Rendering the original upstream template produces terminal text `'\n'` and heading `option_'\n'`, each with exactly one backslash. The check parses the rendered DOM; it does not inspect Ruby or JSON string representations. |
| L-03: links, heading IDs, zero paths | Still present | The small fixture yields zero heading IDs, zero SVG links, and 47 paths ending in `h0` or `h0.0`. |
| L-04: JSON grammar output | Not implemented | The current CLI help has no JSON dump option. The library adapter supplies this site's IR. |
| L-05: comments between a rule name and colon | Fixed upstream | The fixture `start /* rule comments are valid */: ...` parses, and unmodified Perl `v5.44.0/perly.y` produces 139 unique rules. |

Reproduce using the bundled source:

```sh
bundle install
bundle exec exe/rdc fetch perl@5.44
bundle exec ruby scripts/check_lrama_master.rb
```

The checker verifies the loaded checkout's Git SHA, renders `test/fixtures/frontends/sample.y` with `Lrama::Diagram.render`, parses that HTML with Nokogiri, verifies exact newline spelling, parses the original Perl file without preprocessing, and prints a JSON result. JSON renders a single literal backslash as `\\`; that representation is not evidence of a double-escaped DOM label.

The original planning documents describe Lrama's released 0.8.0 behavior and retain their historical measurements. They must not be read as current-master results: L-02 and L-05 no longer need upstream fixes. There is no Perl comment-stripping workaround in the current manifest.

The site's renderer independently supplies valid CSS, viewport metadata, native SVG links, stable IDs, accessible labels, and omission of zero-length paths. These fixes do not alter the upstream result checked above. A [local patch and PR draft](upstream/README.md) covers remaining diagram issues, with a separate JSON-output proposal. No issue or pull request has been posted to Lrama by this implementation.
