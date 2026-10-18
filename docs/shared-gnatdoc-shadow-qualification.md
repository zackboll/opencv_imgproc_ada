# GNATDOC-008C — merged-enhancer Imgproc shadow requalification

## Current GNATDOC-008C transition

**Current disposition: HOSTED_CI_PENDING. No production migration is authorized.**

The existing PR #72 starts at `f2989da6c6a593f6196d1d989be0b2d126743dc6`.
Its original main baseline remains `9ce22ae5ab70008e1147475a9e6d7baef82f1df0`.
The new immutable enhancer pin is `53a321915da2c5a02a54581040673b61f8595b25`,
the actual merge of shared PR #9, independently checked against fetched main.
It is not feature HEAD `6187976c53cf42783b82a15a587ae458adf17a18`.
The former pin is `f52dcfe37dc2819d86e72e1c38425e5e49d914eb` and is rejected.

The proposed reviewed transition lives in
`docs/evidence/gnatdoc008c/authority-transition.json`, protected by the runner's
literal SHA-256 `bf399766834fd80fdbf359486abcd504d2e290b59244dda5097e01e16e770bab`.
It binds the exact five historical trust digests, canonical source/native/input
maps, Core acquisition and manifests, configuration and publication policy.
Neither the runner nor the collector can create or approve that authority.
Independent reviewers must review this record and its literal digest together.
All historical GNATDOC-008 files remain unchanged, including the 66-label
failure, old red CI and the historical authority's old enhancer binding.

The approved publication differences against the historical shared inventory
are exactly `api/gnatdoc-navigation.js` (shared declaration history),
`api/index.html` (source-order label correction), and `api/presentation.json`
(matching output metadata). Every other file must remain byte-identical;
native integrity is independently checked, not waived for these differences.

The browser suite retains the original 1,840 named checks and adds real-site
source-order profiles, declaration query state, repeated Back/Forward,
active-selection deduplication, deep-link reload, package/native bookmarks,
search history, keyboard operation and invalid/duplicate/wrong-owner queries.
The new tests wait on URL, control readiness and actual native headings, and
reacquire the iframe after transitions. A sentinel proves the outer API
document stays loaded during declaration traversal. No arbitrary sleeps.
The retained local-type and external-Core click assertions now reacquire the
frame after each navigation and wait for the genuine destination heading;
previously they retained one frame and checked anchor count immediately after
URL arrival. The expected links, anchors, Back/Forward sequence and check names
are unchanged. This separates URL acknowledgement from loaded native content.
The original 24 observed mutations remain, with 12 additional rejection checks.
Tampering runs serially before browsers; restored hashes and reconstructed
publication must match the qualified site before browser execution.

Fresh results belong only in `docs/evidence/gnatdoc008c/` and isolated
`/tmp/gnatdoc008c/` workspaces. The readiness recorder fails closed on incomplete
or old-pin evidence, requires current qualification-report digests and exact
site inventories, and exits nonzero unless the complete local matrix passes.
Local success means `HOSTED_CI_PENDING`, never exact-head hosted success.
Final hosted run IDs and final consumer identity must be recorded separately
after the normal push to the existing branch. No merge or auto-merge is allowed.

Production blockers remain independent review, version-stable independently
verified Core HTTPS hosting, explicit migration approval and production release/
deployment qualification. The reserved Core 0.4.1 mapping remains offline only.

### Executed merged-pin results (not final-head hosted credit)

Two new complete local builds passed unchanged legacy generation, independently
generated pristine Imgproc/Core native bytes, shared reconstruction, source/anchor
preservation, two-copy determinism and byte-idempotence. The second build executed
164 documentation tests and all six compiled landing/guide examples. Coverage is
1,512/1,512 and warning delta is 0 added/0 removed. Native declarations are 314/314,
local links 326 and reserved offline Core links 549; landing, five guides and guide
CSS remain byte-identical. The unchanged navigation oracle reports 314 entries,
zero incorrect source-order labels, no missing or duplicate destinations.

The first complete Chromium run passed 1,992 checks: all original 1,840 retained
and 152 added history checks. Both completed adversarial runs rejected 36/36
observed mutations and restored exact inventories before browser use. These are
executed intermediate-head results, not proof for a later head. A final fresh
workspace and exact-head hosted workflows must pass before independent-review
readiness. Checked-in current reports identify their actual tested consumer SHA.

The final local workspace `/tmp/gnatdoc008c/full-final` completed the entire
current driver matrix: 164 documentation tests, 6 executables, 36 restored and
independently verified mutations, 1,992 browser checks (1,840 original + 152 new),
zero navigation mismatches and all native/link/coverage/warning/guide gates.
`docs/evidence/gnatdoc008c/readiness.json` records complete local evidence and
`HOSTED_CI_PENDING`. The freshly generated inputs were consumer
`55d2f3d9d09d9856e6744bfdec4ba2de3d8398b5`; newer boundary-test/recorder hardening
was executed explicitly against those reports and does not pretend to be a
rebuild of a later commit. Exact final-head hosted CI remains mandatory after
committing the review evidence. Its final SHA/run IDs belong in the PR description
and immutable PR comment, avoiding a self-referential evidence commit hash.

## Historical GNATDOC-008 record (unchanged evidence)

## Disposition and scope

**Historical disposition: BLOCKED_BY_SHARED_TOOL. Production migration is not complete.**

This is a PR-only, non-deployable review integration. It neither replaces the
existing generator nor publishes a second documentation site. The original
`documentation.yml`, `generate_docs.sh`, Ada sources, examples, version 0.2.1,
`opencv_core = "~0.4.1"`, coverage/warning baselines and Pages jobs are unchanged.
The shadow workflow has only `contents: read`, no push trigger, no Pages action,
no OIDC identity and its own concurrency group. Review artifacts deliberately
include `NON-DEPLOYABLE` in their names. Branch protection is not changed.

## Immutable identities and authority

| Input | Identity |
| --- | --- |
| Freshly fetched starting `origin/main` (clean tree) | `9ce22ae5ab70008e1147475a9e6d7baef82f1df0` |
| Shared GNATDOC-007 merge, verified ancestor of fetched enhancer main | `f52dcfe37dc2819d86e72e1c38425e5e49d914eb` |
| Indexed Core 0.4.1 origin, verified in the actual Alire lock | `386c5360ac51f2b62e522853d94290aec4ee14a0` |

The consumer baseline is **exactly** the Imgproc revision reviewed by
GNATDOC-007. The copied authority documents are not reduced build fixtures:
`consumer-input.json` binds the complete historical consumer input selection;
`authored.json` binds all five Markdown guides, their order, landing source,
original stylesheet, Ada examples, build projects and pristine native bytes;
`core-input.json` and `core-types.json` bind the complete Core acquisition.
Their immutable upstream hashes are retained and checked in the runner.
`authority.json` separately binds the consumer-owned TOML configuration.

Equivalence is not assumed from the filenames: local independent generation
reconfirmed the three Imgproc native file hashes, the complete Core native
artifact, the 203-type manifest and authored output parity. Source bytes are
checked before staging. Only the actual public `src/opencv-image_processing.ads`
is staged for enhancer inventory. Private units remain in the real build but
cannot become public documentation packages. No native filename is synthesized.

The full Core 0.4.1 source is independently checked out and built. Its original
release predates documentation projects; the runner uses the exact, hash-checked
GNATDOC-005 documentation-only GPR harness. This harness selects real public
sources and the production compiler switches; it does not change Core source.
The Alire build cache source bytes are separately checked against that source
identity, not inferred from the neighboring checkout.

There is deliberately **no default contract-generation command**. Updating any
authority requires a separate acquisition/reconciliation and explicit review of
the new hashes. CI cannot regenerate and approve whichever source it finds.

## Original consumer oracle

The existing workflow owns:

* native prerequisites, Alire 2.1.1, GNAT 16.1.0 and GPRbuild Alire 26.0.1;
* pinned Markdown dependencies (`markdown-it-py==3.0.0`, `mdurl==0.1.2`);
* documentation helper tests, including validator/coverage/navigation/guide
  mutations, source-comment checks and type/presentation checks;
* the real library build, public native GNATdoc 26.0.0 (20260415), five legacy
  postprocessors, complete HTML validation and warning/coverage ratchets;
* deterministic regeneration and idempotent postprocessing;
* compiling and running the landing example and all five guide examples;
* review site/diagnostic artifacts and main-only Pages upload/deployment.

The shadow runner executes that unchanged process in a detached isolated copy.
It preserves legacy output and command logs; it does not modify the original
checkout's `_site`. Native-only shadow generation is executed separately twice
with the original public project, leading style, public scope and warnings.
No legacy theme, link, highlighting, navigation or guide postprocessor touches
the pristine input. Every native output byte is matched to reviewed authority.

The original full validator is authoritative on the legacy site. It is not
rewritten to accept the shared index/theme: its exact presentation metadata,
script bytes and Core package-link policy intentionally differ. Shared output
is independently reconstructed by `gnatdoc-enhancer verify`, and native
signatures, visible text, links and anchors are additionally compared to pristine
input. The **unchanged** consumer coverage and warning checks run on native and
enhanced shadow output, not a replacement shared coverage metric.

## Independent results and differences

The first complete isolated local structural integration established:

| Requirement | Observed |
| --- | ---: |
| Public packages | 1 |
| Native declaration sections | 314 |
| Preserved native code snippets (including member snippets) | 467 |
| Shared local type references | 326 |
| Shared offline Core type references | 549 |
| Missing native anchors / unexpected declarations | 0 / 0 |
| Consumer coverage (legacy, pristine, enhanced shadow) | 1,512 / 1,512 |
| Warning delta | 0 added, 0 removed |
| Original documentation tests | 155 passing |
| Compiled/executed examples | 6 / 6, exit 0 |
| Landing, guides, stylesheet | all 7 outputs byte-identical |
| Independent enhanced copies / repeat enhancement | byte-identical |
| Consumer integration tamper cases | 24 observed mutations rejected, including failed-enhancement atomicity |
| Expanded Chromium matrix | 1,840 executed assertions, 0 failures |

The legacy linker reports **331 Imgproc / 551 Core package links**, not the
shared tool's 326 / 549 type links. These are different classifications: legacy
counts include broad source-name/package links. They must not be conflated or
reported as byte parity. Genuine native text, identity and anchors are preserved;
the shared tool's stricter source-owned type reference counts match GNATDOC-007.

### Reproduced shared-tool defect — do not waive

`ada_gnatdoc_enhancer.navigation.operation_entries`, at the pinned merge,
numbers overloaded entries with `len(resolved) + 1`, where `resolved` contains
**all preceding declarations in the category**, and iterates native sections
rather than the consumer's source-order overload model.

On real Imgproc output, for example:

* `Filter_2D` is labeled `(17)` / `(18)`, not overloads 1 / 2;
* `Sep_Filter_2D` is labeled `(44)` / `(45)`;
* `Match_Template` is labeled `(32)` / `(33)`.

The independent consumer comparison finds **66 incorrect overload labels**.
`scripts/compare_shared_gnatdoc_navigation.py` uses the unchanged original
source-profile/anchor reconciliation and exits nonzero. Its report retains
every affected source profile, native href, expected ordinal and actual label.
This is **Incorrect output**, not an arbitrary theme difference. The consumer
does not patch, relabel or reorder shared output to hide it. A correction belongs
in a separately reviewed shared-tool task and a newly approved immutable pin.

Authored guide entry-point mappings are a separate GNATDOC-007 path and meet
byte parity; that success does not excuse the API browser's incorrect labels.
Operation category grouping/search and layout differences remain subject to the
executed browser report. The shared category groups are static sections rather
than the legacy collapsible details; this is recorded as a shared presentation
difference, not tested using invented legacy DOM selectors.

## Reproduction

Use an immutable detached enhancer checkout with `origin/main` fetched. Install
that directory non-editably into an isolated Python environment with the pinned
`guides` extra. The runner verifies HEAD, detached state, main ancestry, repository
URL, installed version (`0.1.0.dev0`), `direct_url.json`, every installed module/
asset byte, `pip check` and the resolved Python dependency list. No floating
release/PyPI enhancer is accepted.

From the consumer checkout, substituting absolute directories:

```sh
/absolute/shadow-tools/bin/python /absolute/imgproc/scripts/qualify_shared_gnatdoc_shadow.py \
  --expected-head FULL_TESTED_CONSUMER_SHA \
  --enhancer /absolute/pinned-enhancer --core /absolute/core-0.4.1 \
  --workspace /absolute/new-shadow-workspace
/absolute/shadow-tools/bin/python /absolute/imgproc/scripts/qualify_shared_gnatdoc_negative.py \
  --workspace /absolute/new-shadow-workspace --enhancer /absolute/pinned-enhancer
/absolute/shadow-tools/bin/python /absolute/imgproc/scripts/qualify_shared_gnatdoc_browser.py \
  --workspace /absolute/new-shadow-workspace
/absolute/shadow-tools/bin/python /absolute/imgproc/scripts/compare_shared_gnatdoc_navigation.py \
  --workspace /absolute/new-shadow-workspace
/absolute/shadow-tools/bin/python /absolute/imgproc/scripts/record_shared_gnatdoc_shadow.py \
  --workspace /absolute/new-shadow-workspace
```

The navigation command was expected to **fail on the historical pin**. A workflow
failure here is evidence of a functioning independent gate, not readiness.
Never run tamper tests concurrently with browser assertions against the same
site: mutations must finish and restore all bytes first.

The workflow uploads real generated legacy/shadow sites, pristine inputs,
Core-native output, actual Alire locks and hashed command logs as review-only
artifacts. Source-controlled evidence is compact JSON, not regenerated sites or
dependency build trees. Local logs/workspaces remain under `/tmp/gnatdoc008`.

## Browser and external publication boundary

The consumer browser driver executes individual Chromium assertions at 1280px
and 390px, light/dark, JavaScript enabled/disabled: landing and every guide,
guide navigation, direct heading fragments, source-backed API entry points,
Back/Forward, keyboard focus/activation, tables, operation search/categories,
native/local anchors, Core declarations and page errors. Failures remain in
`browser.json`; browser success is never inferred from static checks.

External type URLs are exclusively
`https://core.invalid/386c5360ac51f2b62e522853d94290aec4ee14a0/api/`, explicitly
`offline-test`. Chromium intercepts these URLs with the actual verified Core
artifact and checks declaration signatures. This does **not** verify production
HTTPS hosting. Original authored general project website links are retained
byte-for-byte and do not acquire immutable dependency-artifact status.

## Review handoff

Consult `docs/evidence/gnatdoc008/` and exact-head Actions artifacts for executed
results and SHA-256 inventories. Readiness requires all independent reports;
missing evidence never becomes a pass. The known navigation mismatch prevents
`SHADOW_INTEGRATION_READY_FOR_REVIEW`, even when structural verification passes.
The PR must remain open, non-draft and unmerged, with auto-merge disabled. No
release, tag, production URL policy or deployment adoption is authorized here.