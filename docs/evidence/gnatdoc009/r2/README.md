# IMGPROC-GNATDOC-009R2 — production release migration checkpoint

**Disposition at initial implementation checkpoint: `HOSTED_CI_PENDING`.**
This is not `READY_FOR_INDEPENDENT_REVIEW` or production-policy approval.

Fresh fetch confirmed starting PR head
`a4d4a2edbc7cae49cf07a6d1e9f753f8d833d569`, tree
`3d352773a17a3be1765e5c877b4b834959da1ddd`, and main
`40ab7180fb2dc96dd5dad5fe42f7ad07b5248d8a`, tree
`324bea9dbff9840cd23637934cbace0ec11f970f`. Normal merge
`7ba517e2f9fd25d85b303bc36ded7895ab7ce6fd` preserves both original PR
commits and all merged PR #80/#82 work. No rebase, reset, amend or force-push.
The existing branch is checked out at
`/home/zboll/git/opencv/imgproc-gnatdoc009`, not the initial IDE worktree.

## Authority and independent review

The installer now consumes the official v0.1.1 release with the user-specified
annotated tag, source commit/tree, wheel, provenance, sdist and SHA256SUMS
digests. Installed archive/member/source/asset/metadata/launcher/origin checks
and tamper controls passed. All previous v0.1.0/R1 evidence remains unchanged.

The additive Core proposal identifies current successful deployment
`7348179998`, source `33a2a4f3b83606a5c779b8a93abeb6c91fa49a21`, tree
`454fb0fa3a128e638a1d7d85f345c7904f296877`, documentation run `40433988181`,
review artifact `12702919800`, Pages artifact `12703258126`. All 209 hosted
files matched immutable review bytes and Pages bytes. All 14 referenced exact
source/native declarations, filenames, anchors and snippets match indexed Core
0.5.0. Deployment was unchanged before/after comparison. This is NOT dynamic
authorization of arbitrary live content, nor automatic production approval.

Candidate `external_type_target = "_top"` implements the explicitly requested
direct-fragment/top-level design. All 586 source-offset occurrences, labels,
identities and URLs reconcile; all targets are `_top`. The independent merge
reviewer must approve the additive production policy. Historical R1 remains
`policy_approved: false`. Release-only browser compatibility acceptance is not
relabelled as production authority.

## Implementation boundaries

The production generator builds the normal indexed dependency, generates
pristine GNATdoc 26.0.0, source-matches native destinations, stages an isolated
API-only copy, verifies official installed v0.1.1, runs inventory/enhance/verify,
then performs consumer-owned source/native checks. Authored pages use the
original PR #80 renderer. Full-site validation separately reconstructs landing,
five guides, assets and 55 source-qualified example links. Toolkit API-only
verification is not represented as authored-page verification.

The five legacy API presentation steps no longer execute in production.
`review_legacy_docs.py` is the explicit same-pristine-input comparison oracle.
Every final file is classified by `compare_production_docs.py`; unclassified
changes fail. Native declarations, source text, visible documentation and
anchors remain exact; ordered navigation has 329 operations; coverage remains
1,596/1,596, warnings zero; local links are 350 (348 retained plus two
source-proven constant type marks); all six examples compile and execute.

Browser testing exposed loss of authored focus/layout CSS in the API theme.
Consumer-owned `gnatdoc-authored.css` restores those rules without modifying
released assets, renderer code blocks or their source text. Landing and guide
page changes are limited to the explicit additional stylesheet link; identical
authored assembly is required on both legacy and shared sides. Shared palette
changes are version-bound; focus controls are independently browser-checked.

The complete authored Chromium matrix passed (1280/390, light/dark, JS on/off)
against genuine live Core HTTPS with no Core interception. Exhaustive API
browser qualification and exact-head hosted qualification are recorded
separately as they complete; partial browser runs are not all-matrix passes.

## Preserved baseline failures

`baseline/main-verify-live-job.log` is the exact failed main job log from run
`39701648387`, job `119604137363`; build/deploy succeeded. Failure artifact
`12398016127`, ZIP SHA-256
`76931843bc3e9b21198341c5086fcfac24776ff71a7fd176622fbe80b831e96e`, contains
the full reconstruction traceback. An isolated exact-main clone reproduced
`CrossReferenceError: missing Core specification: .../core/src/opencv.ads`.
Cause: highlighter's assumed sibling checkout ignored the resolved dependency.
No fake directory or symlink was created. The fixed helper accepts the explicit
resolved path; the new real isolated-generator regression passed and produced
byte-identical final output without a sibling `core/` directory.

Run `39701648338` predates R2. Its Windows job `119572024900` failed fetching
MSYS2 imath signature bytes from ftp2.osuosl.org (slow transfer), then failed
system OpenCV acquisition. Intel macOS job `119572024910` timed out Alire's
solver with missing Core/OpenCV/pkg-config, then could not resolve
`opencv_core.gpr`. Exact logs are retained in `baseline/`. Neither failure is
counted as success or corrected by changing library/platform policy here.

## Remaining exact-head gates

Final local full-site rechecks, complete API browser matrix, current Core
before/after verification, historical 008C campaign, exact-head hosted docs and
required CI, immutable final candidate artifact download/equality, remote/PR
head agreement, final tree, PR description and checkpoint comment. PR-only
acquisition stays non-deployable; verify-live stays post-merge/main-only.

No public semantic validation is duplicated in the C++ shim. Ada/C++ sources,
library manifests and public ABI are unchanged.