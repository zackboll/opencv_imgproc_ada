# IMGPROC-GNATDOC-012: production enhancer v0.1.1 → v0.1.5

Starting main `2160fe7a6bf612eb0b8e85b06e5e011e0c253521`, tree
`613d3552869fcecde7cbf10b18445b9b2acab32b` (PR #81 merged). Historical
GNATDOC-008/009 R1–R4 evidence is unchanged. This directory replaces no earlier
record.

## v0.1.1 production baseline (retained, not re-qualified)

`baseline-main-ci.json`: merged-main documentation run
[41549770007](https://github.com/zackboll/opencv_imgproc_ada/actions/runs/41549770007)
succeeded: `build`, `deploy` and main-only `verify-live` (same-run live
reconstruction and live browser). Review artifact `13193077761` and Pages
artifact `13193377777` each contain the same 14 files. A local, clean-worktree
v0.1.1 regeneration of `2160fe7` reproduced all 14 uploaded file digests
exactly; that publication is baseline **A** below.

## Official v0.1.5 acquisition audit

`starting-identities.json`, `release-archives.json`, `release-install.json`.

* Annotated tag `c6ca2b44…`, commit `0120bee2…`, tree `01900ddb…`; fetched
  independently with redirects disabled.
* Wheel, sdist, provenance and `SHA256SUMS` match their approved size and
  SHA-256 values. `SHA256SUMS` lists exactly the three approved assets.
* 48 wheel members: 42 modules/assets equal to all 42 files under
  `src/ada_gnatdoc_enhancer` at the tag, plus six `dist-info` files. All 48
  `RECORD` hashes and sizes are verified. v0.1.5 adds `examples.py`,
  `external_symbols.py`, `search.py`, `verified_examples.py`,
  `gnatdoc-examples.css`, `gnatdoc-search.css` and `gnatdoc-search.js`.
* Sdist: 1,393 files are byte-identical tagged blobs. The other 8 are exactly
  the setuptools-generated `PKG-INFO`, `setup.cfg` and `egg-info` metadata. The
  sdist member inventory equals the provenance inventory, and its 42 package
  files equal the wheel. The sdist is never installed.
* `METADATA`: no mandatory dependency; only the optional `guides` pins
  `markdown-it-py==3.0.0` and `mdurl==0.1.2`.
* Installed environment: the non-editable `direct_url.json` points at the
  approved wheel. Every installed `RECORD` row is classified. Installed bytes,
  launcher, CLI, module and distribution versions are all `0.1.5`. Install and
  independent recheck receipts are identical.

## Publication comparison (A = v0.1.1, B = v0.1.5)

`publication-comparison.json`: A and B are two complete, independent
generations (separate checkouts, fresh Alire resolution to the identical
`alire.lock`, fresh GNATdoc 26.0.0 native output, separate enhancer
environments). Their native inputs are identical. 11 of 14 published files are
byte-identical, including the package API page, both CSS files, the landing page
and all guides.

| File | Cause (tagged upstream source) | Classification |
| --- | --- | --- |
| `api/index.html` | `27341756` `navigation.py` `CONTROL`: "Search documentation" → "Filter navigation links" | Presentation/accessibility label only. Replacing that one label reproduces A's index byte-for-byte |
| `api/gnatdoc-navigation.js` | `0eeeadbb` (GNATDOC-019): default-router `reveal()` after matching load/hash, Back/Forward and `pageshow` | Navigation behavior. Destinations, URL, query and history semantics unchanged. The bytes are the exact tagged v0.1.5 asset |
| `api/presentation.json` | version-bound metadata | `enhancer_version` and the two `output_sha256` entries above; all other fields equal |

Declarations (329, including 193 subprograms), source text, categories,
profiles, overload navigation, native anchors, 586 Core occurrences across 14
identities with `target="_top"`, and 350 local links are unchanged.
`ci-mode-comparison.json` is the same differential with the v0.1.1 API rebuilt
by the installer retained at `2160fe7`. Its reconstructed baseline equals A
byte-for-byte. CI runs this mode, plus `test_enhancer_upgrade.py` mutation
controls, on every build.

## Local qualification (`local-tests.log`, `determinism-and-examples.log`, `browser/`)

* Candidate generation: 0 GNATdoc warnings, 1,596/1,596 documented, consumer
  source/native and complete-site oracle passed. Regeneration (fresh
  `alr update --online`) was byte-identical, and repeat enhancement was idempotent. The
  isolated-docs test passed, and all six authored examples compiled and ran.
* Unit/mutation suites: released acquisition (including new RECORD, dependency,
  checksum and provenance negative controls, plus installed tampering),
  production Core links, current Core, Core source authority, warnings,
  coverage, comment-only, type links, guides, examples, live-docs verifier,
  shared production mutations and the upgrade differential all passed. The first
  `test_validate_docs`/`test_gnatdoc_navigation` lines in `local-tests.log` were
  run without `DOC_LEGACY_ORACLE`. CI always provides it, and the reruns with
  it passed (43 and 11 tests), as did production parity classification.
* One local regeneration attempt failed closed at the Core source-authority
  gate because Alire's solver timed out ("solution incomplete") while Chromium
  was running. A later rerun with nothing else running resolved the exact
  indexed Core 0.5.2 and succeeded.
* API Chromium campaign at 1280/390 px, light/dark, JavaScript on/off: 329
  operations, 586/350 occurrences, direct reloads, filter, keyboard and mouse,
  plus the new v0.1.5 checks.
* Negative-first (`browser/`): the exact filter label fails on A. Re-selecting
  an already-loaded declaration after scrolling away leaves it off-screen on A
  (34,009 px / 45,024 px) and reveals it at the top on B. History
  Back/Forward/reload visibility passes on both, so it is retained as a
  non-regression guard.

**Not runnable in this sandbox:** the environment's egress policy refuses
`zackboll.github.io`, and no authenticated GitHub API token is available.
`qualify_current_core.py`, the 14 live Core destination clicks, and the guide
browser campaign (which follows live Core links) therefore run only in hosted
exact-head CI. The local API campaign omitted only the live-Core loop. Hosted
results are recorded in the PR.
