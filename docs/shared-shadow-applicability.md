# Historical GNATDOC-008C applicability — IMGPROC-API-001-R1

This is a workflow-scoping policy, not an authority transition or a production
migration. The immutable historical authority and every previously recorded
evidence file remain unchanged. The qualifier, negative controls, browser,
navigation comparator and readiness recorder are also unchanged.

## Why scope is explicit

GNATDOC-008C qualifies consumer production baseline
`9ce22ae5ab70008e1147475a9e6d7baef82f1df0`, with last integration consumer
`3722ac594c266741eb2735c99bb0cd21d165274d`, against enhancer merge
`53a321915da2c5a02a54581040673b61f8595b25`. Its exact source hashes, 314
declarations and 1512 coverage items cannot qualify a newly extended public
API. PR #73 legitimately added three declarations; running the historical
source-identity gate directly against its production sources correctly
rejected the mismatch but incorrectly applied a historical campaign to a
new API feature.

## Applicability and fail-closed execution

The `shadow` job still starts on **every pull request**, without path/branch
trigger filters or a job-level skip. It runs focused applicability controls
and compares the complete Git merge-base-to-head path inventory, with rename
detection disabled so both old and new names are inspected. Unknown or missing
revisions and mismatched checkout identity fail, not become non-applicable.

Changes to the shared-shadow workflow, shared integration/qualification scripts
and tests, shadow configuration/policy, or documentation evidence require
**FULL_HISTORICAL_QUALIFICATION_REQUIRED**. This includes mixed integration/API
changes. Ordinary API/documentation changes outside that integration scope
report **NOT_APPLICABLE_API_FEATURE**, not a historical qualification pass.
Changing general API documentation tools is still qualified on the current
API by the regular workflow; this historical campaign does not grant those
changes authority over its frozen baseline.

The policy is implemented in `scripts/shared_shadow_applicability.py` and
reviewed with its tests and the workflow in PR #73. Applicability is not chosen
by a label, branch name, commit message, or caller-supplied boolean. This R1
changes the workflow itself, so it **is applicable** and must execute the full
historical campaign rather than taking the feature-only non-applicable route.

For applicable changes, a new isolated checkout starts at immutable consumer
`3722ac594c266741eb2735c99bb0cd21d165274d`. Only shared-integration/evidence
paths are overlaid from exact PR HEAD, including deletions. The preparation
tool refuses symlinks/non-regular overlay entries. No production source or
general documentation-tool bytes are taken from the feature branch. The
original qualifier then runs against an isolated local commit containing
exactly those bytes. Its original Git-diff, literal authority-digest, source,
configuration, pristine/native, dependency, determinism and publication checks
all execute without alteration. Tampered historical evidence is copied as-is
and must fail its original hash check; nothing is regenerated or reauthorized.

`shadow-source-binding.json` records actual PR HEAD, historical consumer,
authority base, isolated tested commit and SHA-256 for each overlaid file
(null for deletion). This synthetic local commit is **not** PR HEAD; the
report explicitly scopes the qualification to the historical consumer.
Historical success is never represented as current-feature API qualification.

Adversarial controls require successful full generation. Browser controls
require successful generation and adversarial checks; parity requires browser
success; readiness requires parity success. No downstream command runs merely
because an earlier step failed. The unchanged commands independently validate
their evidence bindings and fail nonzero. Artifact upload is always attempted,
including failures, preserving the applicability/source-binding records and
any available failure reports. Errors are not converted to skipped success.

For a non-applicable PR, the job finishes successfully with its explicit
non-applicability report in the Actions summary and uploaded JSON artifact;
no generated evidence, browser, parity or readiness result is claimed. Thus a
required `shadow` check is never left pending by workflow trigger filtering.

## Current API remains independently qualified

`Ada API Documentation` continues on every PR. It generates and checks the
exact current public API, zero-warning and zero-gap ratchets, parameter/comment
attachment, mutation controls, navigation, guides, examples and deterministic
regeneration. Full Git history is checked out so the inventory tests can prove
that all 314 pre-feature declaration identities remain, plus exactly three new
overloads: 317 declarations, 187 subprograms, 1534 coverage items. The two
Box_Filter profiles and both Canny profiles are checked separately, including
misattachment mutation controls. No immutable documentation baseline is edited.

## Local correction evidence

Original/reviewed feature HEAD:
`319dca4ab0f83a29d8599f796e4d567536c74396`; fetched main remains
`6715ed13ee8d2ea0f4ac089722ed926cfef77eb6`. No intervening changes existed.

The GNAT12 negative control now requires source-qualified warning/error
diagnostics with variable line/column positions. Default/Ada2012 success,
forced Ada2022 failure, obsolescent aggregates, ambiguous Append and all actual
representation checks remain required. A disposable Debian 12 Podman container
provided real GNAT12 native and AArch64 cross frontends, using the workflow's
actual Core snapshot `c0709f864a2f426c40eeaf1d21486c6d9859a741` (no stubs).
Both four-test campaigns and both C++ ABI compile-only layout controls passed;
ELF headers identify x86_64 and AArch64 respectively. Compiler modes were not
changed. Production Ada/C++, API contracts, AUnit registrations and platform
runtime isolation are byte-identical to reviewed HEAD.

GNATdoc generation: zero warnings, complete 1534/1534 coverage and site/link
validation. The normal Alire build and AUnit suite retain 1147/1147 success.
Native Canny/Box_Filter tests need no new version campaign for this R1 because
no production or native test code changed; original exact-version evidence
remains scoped to those unchanged bytes. Exact corrective SHA and hosted run
results are recorded on PR #73 after normal commit/push, not inferred here.

Windows remains intentionally post-merge/manually dispatched; skipped Windows
is not a pass. No merge, auto-merge, tag, release, production shadow migration,
or independent approval is authorized by this correction.