# IMGPROC-GNATDOC-009R4 — current authenticated Core compatibility

Status: hosted qualification passed on the code head `8407c12c4df1e9b686042bff2a8c6ce114120a00`
(tree `9a3cb3f9c29c7a8707e19a6d4c3a33647987f003`). The commit that adds this
evidence changes only `docs/evidence/gnatdoc009/r4/`.

## Defect corrected

Independent review IMGPROC-GNATDOC-010 (blocker B1) found that
`scripts/qualify_current_core.py` (R3) required:

- Core's newest `github-pages` deployment to be `7348179998` (source
  `33a2a4f3b83606a5c779b8a93abeb6c91fa49a21`, run `40433988181`);
- the retained artifacts `12702919800` and `12703258126` to exist with fixed
  digests;
- all 209 live Core files to be byte-identical to that artifact.

Core has since redeployed several times. The newest deployment is `7484574049`
(source `0798900142660fb7ac5b9ab395c808e911242fa7`, run `41387613310`), and
Pages artifact `12703258126` was deleted. As a result:

- the documentation build failed before the Pages upload, both on rerun and on
  the post-merge push;
- `verify-live` failed in the same way;
- every future unrelated Core documentation deployment would have blocked
  Imgproc again.

## Correction (no change to Imgproc output, dependencies or destinations)

The following are unchanged:

- the indexed Core 0.5.2 dependency and its 392-file authority;
- the 14 approved identities and URLs;
- authored examples and guides, `src/`, ABI and `alire.toml`;
- official enhancer v0.1.1;
- all historical R1/R2/R3 evidence.

`qualify_current_core.py` now authenticates the *current* publication on every
run. `docs/documentation.md` describes the seven-step policy in full. In brief:

- the indexed authority is re-established;
- the deployment, run, jobs, ancestry, artifacts and digests are authenticated;
- the review and Pages inventories must be identical, and archive extraction
  is safe;
- the deployed source declarations of all 14 types must match;
- each native anchor must be unique and bound to the correct declaration;
- the two pages fetched over HTTPS must equal the authenticated artifact bytes;
- race detection runs within one qualification and between the pre-browser and
  post-browser runs.

No file count or whole-site digest is pinned.

`qualify_shared_production.api_semantics` no longer compares inline R3
deployment numbers. It verifies the hash-pinned historical R3 destination-design
record (direct fragments, `_top`, indexed 0.5.2, 14 identities) together with
the hash-pinned referenced-type authority. Callers updated:

- `.github/workflows/documentation.yml` (pre-publication step and post-browser
  `--expect` recheck);
- `scripts/verify_live_docs.py` (post-merge reconstruction).

## Local qualification

`current-core-tests.log` records 34 tests and all pass. The fixtures are:

- a real Git commit of the indexed Core specifications;
- real upload-artifact ZIP files and upload-pages-artifact ZIP/TAR files;
- real digests;
- GNATdoc-shaped native pages carrying highlighting.

The suite covers:

- acceptance of a new deployment;
- acceptance of unrelated Core changes;
- skipping a failed newer deployment and rejecting an unsettled one;
- changed, private, ambiguous and mis-owned declarations;
- wrong-but-valid, swapped, missing, duplicate, substituted, non-declaration
  and wrong-owner anchors;
- 20 provenance identity mutations;
- unsuccessful and incomplete deployments;
- tree mismatch;
- wrong digests and tampered bytes;
- unsafe ZIP and TAR entries (traversal, absolute path, symlink, hard link,
  device, directory, duplicate, unexpected type, oversize);
- inventory divergence;
- stale HTTPS content;
- a deployment change and an unsettled redeploy during qualification
  (`CORE_DEPLOYMENT_RACE`);
- forged expected provenance;
- a changed indexed dependency;
- rehashed source authority, referenced types and the policy record;
- R3 identities no longer acting as acceptance criteria.

Ten deliberate weakenings of the checker were each detected by specific tests:

- live comparison;
- inventory equality;
- the race check;
- the snippet check;
- the push-event check;
- the digest check;
- declaration ambiguity;
- anchor uniqueness;
- unsettled-state handling;
- the deploy-job binding.

The complete offline Python suite (18 modules) also passes.

## Hosted qualification

The following runs are on code head `8407c12`. Code head `bd05e0d` had earlier
passed the same gate without the log summary: Documentation run `41393910816`,
all 11 workflows.

| Workflow | Run | Result |
|---|---|---|
| Ada API Documentation | 41397117818 | build success. `deploy` and `verify-live` are main-only and were skipped |
| Released GNATdoc acquisition | 41397117624 | success |
| Shared GNATdoc shadow | 41397117623 | success |
| Cross-Platform Bridge | 41397117596 | Linux, macOS ARM64 and macOS x86_64 succeeded. Windows is main-only and was skipped |
| Debian 12 installed consumers | 41397117639 | success ×2 |
| AArch64 full cross install | 41397117617 | success |
| AArch64 target dependencies | 41397117610 | success |
| Cross configuration / AdaCore adapter | 41397117654 / 41397117601 | success |
| GNAT 12 source units | 41397117595 | success |
| Standalone macOS SDK | 41397117602 | success ×2 |

Across 18 check runs, 15 succeeded and 3 were skipped by design. No run was
pending or failed, and no skipped run is counted as a pass.

### Current authenticated Core publication

The following comes from `hosted-core-qualification-pre-browser.json`. The
post-browser `--expect` recheck is byte-identical.

- Deployment `7484574049`: source `0798900142660fb7ac5b9ab395c808e911242fa7`,
  tree `166e938a45ac9085cc9ed0f4aaf16e4b156f8b13`.
- Run `41387613310`: push to `main`, `.github/workflows/documentation.yml`,
  with `build` and `deploy` both successful.
- Review artifact `13117735599`, `sha256:349f4b29…ab19`.
- Pages artifact `13117292259`, `sha256:918bce32…454e`.
- The two artifact inventories are identical: 210 files, a count that is
  recorded but not pinned.
- All 14 destinations passed the source, owner, profile, anchor and snippet
  checks in the deployed commit `0798900`.
- The live HTTPS bytes equal the authenticated artifact:
  - `api/ea2ebcbc…44aa.html` → `48e5b768…f8c2`
  - `api/6913f2e7…b7e9.html` → `deee36ab…a264`

  Both digests also equal Core's own committed current-publication inventory
  (`docs/enhancer-qualification/search-publication-inventory.json` at Core
  `0798900`).

### Imgproc publication

`hosted-publication.json` records review artifact `13121242589`
(`sha256:7e7aa781…dcc5`, 326,588 bytes). It also records the in-job digest of
every uploaded file. All 14 files are byte-identical to the R3-qualified
complete site (`../r3/full-site.json`), so no publication differences were
introduced.

The following also passed:

- the guide matrix: 1280/390 × light/dark × JS on/off;
- the API matrix with the project prefix, including actual top-level navigation
  to the live Core destinations;
- generation determinism and idempotence;
- compiled examples;
- the full validator, coverage, navigation, guide, example, live-verifier and
  shared-production suites;
- 34/34 R4 Core-gate tests, none skipped.

### Not independently performed in the implementer's environment

The implementer's session could not download artifact `13121242589` or reach
`zackboll.github.io`, because the egress policy denies the Actions blob host
and Pages. The live Core checks above ran in GitHub-hosted CI, as the task
permits. An independent download-and-compare of the final artifact remains
for the reviewer.
