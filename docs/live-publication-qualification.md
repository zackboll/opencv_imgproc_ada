# R2 implementation update

The production reconstruction now uses the official GNATdoc Enhancer v0.1.1
wheel and the independent complete-site validator. API-only toolkit verification
does not authorize the consumer-assembled guides. See `documentation.md` and
`docs/evidence/gnatdoc009/r2/` for release identity, pinned Core publication,
parity and browser gates. The PR #82 source/artifact/HTTP security trust chain
below remains mandatory; `verify-live` remains main-only and read-only.

# IMGPROC-DOC-EXAMPLES-002: live publication verification

Starting main: `3b44846687354f344d078104fe6101bfb7997534` (PR #80 merged).
Branch: `docs/live-example-publication-verification`. The exact tested/pushed
head and hosted results are recorded in the PR, not a self-referential SHA here.
No production Ada/C++, public declarations, ABI, example programs, Alire
dependencies, release artifacts, or frozen shared-enhancer authority are changed.

## Architecture and authority

`scripts/verify_live_docs.py` is a documentation-only, read-only remote client.
Its authority chain is:

1. Explicit full expected SHA and clean exact Git checkout, including no
   untracked source additions or committed symlink inputs.
2. GitHub API evidence for this repository's exact Documentation workflow
   path and workflow ID, main push/manual event, expected SHA, successful build
   and deploy jobs, successful review/Pages upload steps, and successful
   `github-pages` deployment status tied to the same run's deployment job URL.
   The environment URL must be exactly the approved Imgproc HTTPS Pages URL.
   The containing run may still be running its own `verify-live` job.
3. Same-run, unexpired `ada-api-<SHA>` **and** `github-pages` artifacts,
   downloaded by their API-discovered IDs, not by a latest-artifact shortcut.
   Archives are size/count bounded; traversal, duplicate names, links and
   special files are rejected. The Pages ZIP/tar is inspected without unsafe
   tar extraction and must contain the identical qualified file inventory.
4. Independent fresh generation using the unchanged pinned generator, followed
   by exact artifact/reconstruction inventory and byte equality. The existing
   source/native declaration validator, example/guide reconstruction, asset
   checks, fragment checks and coverage ratchets remain mandatory.
5. Bounded HTTP GETs for every qualified file and the canonical landing URL,
   with fixed HTTPS origin/prefix allowlists, no redirects, correct MIME types,
   unambiguous framing and bounded gzip decoding. Decoded entity bytes must
   equal the qualified artifact. Neither HTML nor a manifest establishes the
   deployed commit identity.

The checker adapts the MEL live checker pattern (source qualification before
HTTP, decoded bytes, complete attempts, external evidence); it does not copy
MEL's inventories, enhancer assumptions, or historical evidence. GNATdoc stays
at 26.0.0. Fresh reconstruction intentionally costs another build: an artifact
or manifest alone cannot authorize altered native documentation or assets.

## Examples and hyperlinks

The landing program and five guide programs are read from the committed `.adb`
files. Existing rendering reconstructs the complete escaped/highlighted markup
and source-qualified link identities, including comments, literals, attributes,
operators and final newlines. Categories absent from an actual program are
covered by existing synthetic lexical tests, not falsely claimed as present.
Every program must occur on exactly one page, once. The source resolver—not an
HTML link count—must yield exactly the current **55** reference occurrences.

| Program | Imgproc | Core | Qualification |
| --- | ---: | ---: | --- |
| Landing `example.adb` | 0 | 3 | Exact source, markup, compile/run |
| `filtering_and_transforms.adb` | 0 | 8 | Exact source, markup, compile/run |
| `color_and_representation.adb` | 0 | 7 | Exact source, markup, compile/run |
| `features_and_analysis.adb` | 2 | 11 | Exact source, markup, compile/run |
| `segmentation_and_contours.adb` | 5 | 6 | Exact source, markup, compile/run |
| `matching_and_registration.adb` | 1 | 12 | Exact source, markup, compile/run |

Imgproc links use actual source-matched native anchors, including
`Connected_Component_Set`, `Component_Statistics`, `Contour_Set`, `Histogram`,
and `Phase_Correlation_Result`. Byte equivalence carries the existing complete
local graph/fragment qualification onto the served entities. Wrong-but-existing
declaration anchors are not accepted merely because they resolve.

Core is independently deployed. For all eight approved example symbols the
checker fetches **today's** Core symbol index, discovers the current native href,
and follows it. The target's package heading, unique anchor, type/subtype name
and complete public declaration must match approved indexed Core source.
No historical native hash is constructed or reused. This includes
`OpenCV.Core.Mat`, `OpenCV.Size`, and `OpenCV.Float32_Value`; `Size` is checked
separately because no authoritative example contains that type occurrence.
Changes in Core's public declaration/contract fail closed and require review;
Core's unrelated files are not required to match an old Imgproc artifact.

## HTTP equivalence versus browser behavior

HTTP evidence establishes that each requested live entity equals the exact
qualified generated entity after HTTP compression decoding. It does not prove
layout, keyboard interaction, actual JavaScript routing, accessibility, or the
absence of an unlinked arbitrary URL on a web server without an enumeration API.
The inventory is complete for the approved publication and its references;
unexpected artifact files/linked content are rejected. No finite HTTP client can
prove absence of all unknown, unreachable server paths. There is no Pages write,
redeployment, site mutation, or server-side enumeration in this checker.

The real Chromium matrix adds desktop/mobile (1280/390), light/dark, JavaScript
enabled/disabled, every example's highlighting/overflow, keyboard link focus and
activation, code-region scrolling, local/Core declaration navigation, history,
reload, and console/page-error checks. Browser automation scrolls the actual
code region to test containment, not hardware wheel handling; keyboard
qualification covers focus and link activation. Byte checks and browser checks are both
necessary: one does not substitute for the other. Browser evidence is scoped to
Linux/Chromium, not a universal accessibility or cross-browser certification.

Core's stable `?symbol=` routing **requires JavaScript**. With JavaScript
disabled the browser campaign uses Core's native package/sidebar links and
observed declaration fragment. It does not claim query routing works without JS.

## Evidence, retries and CI

Main-only `verify-live` depends on successful `deploy`, leaving the existing
build/deploy gates intact. It checks `${{ github.sha }}` and downloads artifacts
from `${{ github.run_id }}` through read-only GitHub APIs. Its permissions are
`contents: read`, `actions: read`, `deployments: read`; no Pages write or OIDC
permission is inherited. PR CI runs real offline HTTP and adversarial fixtures.
Playwright and Python Markdown tools remain isolated documentation dependencies.

The verifier emits JSON with source tree/SHA, workflow/run/deployment/artifact
IDs, archive hashes, full inventory byte lengths/SHA-256, six source hashes and
reference ledgers, native type destinations, and per-attempt HTTP comparisons
and current Core destinations. A successful result requires `passed: true` and
one complete passing attempt. Failed attempts retain their own errors; partial
successes never accumulate across attempts. Setup fallback JSON, verification
logs, JSON, and browser evidence upload with `if: always()`, including failure.

CLI defaults to one attempt; CI allows ten complete attempts with thirty-second
intervals. Inputs outside 1–10 attempts or 0–30 seconds are rejected. Requests
have thirty-second socket timeouts and eight-MiB entity limits; artifacts have
32-MiB aggregate and 256-entry limits. This is bounded eventual Pages propagation
readiness, not an unbounded poll of GitHub deployments. Provenance/source errors
fail immediately; only complete live HTTP/Core attempts are retried.

External command capture has one 120-second monotonic deadline covering stdout,
stderr and process exit, not just a final `wait`. Stdout retains its 32-MiB
maximum (or the caller's smaller limit); stderr is drained with a 64-KiB cap,
without saving raw diagnostics to memory or disk. Failure kills the process
group and reaps the child, closing both pipes and the selector. JSON distinguishes
`timeout`, `oversized_output`, and `nonzero_status`; safe diagnostics include
exit status and byte counts, never arguments, credentials or child output.
The main-only job has a 45-minute runner ceiling for tool acquisition, fresh
generation, Pages readiness attempts and Chromium qualification. This ceiling
is a fail-closed operational limit, not a promise to exhaust every retry under
pathologically slow HTTP. Evidence upload retains `if: always()`; GitHub runner
cancellation can still prevent an upload, so setup/job logs remain important.

R1 corrects reviewed head `2a6dedefe98e06a21a3f3b3031b8fa2e19bd18fc` on the
same PR. Original publication evidence is preserved; corrective-head test and
hosted results belong in PR #82, not a replacement publication claim.

```sh
# Run from a clean checkout of EXPECTED_SHA with the qualified documentation
# toolchain and DOC_PYTHON configured as in documentation.md. Evidence is fresh,
# outside the source checkout. gh must have read access to Actions/deployments.
"$DOC_PYTHON" scripts/verify_live_docs.py \
  --expected-sha "$EXPECTED_SHA" --run-id "$DEPLOYMENT_RUN" \
  --attempts 10 --interval 30 --evidence /tmp/live-publication.json

"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_verify_live_docs.py' -v
```

Expected failures: incomplete deployment or missing provenance, expired/missing
artifacts, wrong checkout/workflow/SHA, stale Pages bytes, HTTP/redirect/MIME or
compression failures, changed assets/examples/manifests, broken fragments, or
changed Core navigation/declarations. Inspect `error`, then the failed attempt's
file URL/hash and Core result, the deployment job/status and generator log. Do
not bypass a check, extend allowlists speculatively, or redeploy from the checker.
An expired artifact requires a separately authorized normal documentation run.

## Qualification disposition

Local fresh generation: zero warnings, 1,596/1,596 documentation items,
329 native declaration sections (193 subprograms), eight HTML pages. All six
example executables compile/run. Repeated fresh generation and re-enhancement
are byte-identical. Detailed final browser/test, live deployment and exact-head
hosted CI results are in the PR and final task report. The new main-only job
cannot execute on this unmerged branch: **POST_MERGE_CI_PENDING** until a future
merge. This is distinct from **HOSTED_CI_PENDING** for current PR checks and
**POST_MERGE_DEPLOYMENT_PENDING** for PR #80's deployment.

Stop at independent review. No merge, auto-merge, tag, release or index change.
No public semantic validation is duplicated in the C++ shim; the shim is unchanged.