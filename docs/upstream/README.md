# Reviewable Lrama contribution

These are local drafts; no issue, PR, or upstream merge is claimed. The [master verification](../LRAMA_MASTER.md) records the unmodified baseline. L-02 and L-05 are already fixed and need no duplicate patch.

## L-01 / L-03 patch

[diagram-accessibility.patch](diagram-accessibility.patch) targets master `c8317b55850bc6cd9033ddfbf816377b73f6c7bc`. It adds language/charset/viewport metadata, fixes stroke width, keeps SVG intrinsic size in a scroll region, adds stable rule IDs and native links around entire nonterminal boxes, labels diagrams, removes zero-length path commands, and removes the scripted click navigation. Existing heading assertions are updated. The patch to Lrama remains under its upstream GPL-3.0-or-later license.

Apply to a separate checkout of that commit, then run this repository's check against it:

```sh
git -C /path/to/lrama apply /path/to/railroad-diagram-collection/docs/upstream/diagram-accessibility.patch
bundle exec ruby scripts/check_lrama_patch.rb /path/to/lrama
```

Draft PR title: **Make syntax diagrams readable on mobile and navigable with native links**

Draft description:

> Wide syntax diagrams currently shrink to the viewport, and nonterminal navigation relies on click listeners without heading IDs or browser history. Preserve intrinsic SVG dimensions inside horizontal scroll containers and wrap nonterminal boxes with native fragment links. Add document metadata and diagram labels, correct `stroke-width`, and discard zero-length paths. Existing hover behavior remains available; keyboard focus gets a visible stroke.
>
> Validation: original-master regression matrix, stable-ID/native-link/metadata/label/path assertions on the parameterized-rule fixture, and existing diagram heading expectations updated. The site renderer uses the same stable-ID spelling. Run the upstream full spec suite before submission.

## L-04 JSON output proposal

Expose a CLI JSON dump after parser preparation and validation, before LR-state construction. A versioned record should contain the start symbol; raw symbol IDs; terminal aliases; rules and alternatives; source lines; midrule classification; and parameterized origins (`template`, `args`). Keep these values independent of HTML escaping and SVG rendering.

[The adapter](../../lib/rdc/frontends/lrama.rb) is a working extraction example and [the IR schema](../../schema/ir-v1.json) shows the consumer contract. The upstream format can remain smaller than the site's provenance/metadata wrapper. A `--dump-json PATH` proposal needs maintainer agreement on stability and licensing before becoming a dependency; the current site remains operational with its pinned library adapter.
