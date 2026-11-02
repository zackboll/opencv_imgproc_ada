# IMGPROC-GNATDOC-009R4 — current authenticated Core compatibility

Status: **HOSTED_CI_PENDING** (this file is updated with the hosted results).

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

Pending. Network-dependent checks (GitHub artifact download, public HTTPS from
`zackboll.github.io`, Chromium navigation to the live Core) run in GitHub-hosted
CI on the exact PR head.
