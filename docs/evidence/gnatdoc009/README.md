# IMGPROC-GNATDOC-009 — partial release qualification; not a migration

**Disposition: `CORRECTIVE_WORK_REQUIRED`. Production migration is not implemented
or authorized. Do not publish the experimental shared output.**

## Repository and PR #80

Fresh acquisition confirmed main commit
`496d5d074c9bc987f625d484deb45bcdad174aa0`, tree
`4745352fc3bba1c7bd10a21d0fbcef560aafe7fc`. PR #80 was initially open at
`882bfbf3c195f33288bc2d1bf301df6842dfb298`. A separate worktree was created;
neither its branch nor the upstream enhancer checkout was modified.

PR #80 subsequently merged. A normal `git merge --no-edit origin/main`
fast-forwarded this branch to `3b44846687354f344d078104fe6101bfb7997534`, tree
`d30dc701e2fd7811e3a85a957872f9194f4e4c76`. Its 14 modified paths are recorded in
`pr80-paths.txt`; this change modifies none of them. Its complete rendering
pipeline, full-source examples, syntax highlighting, link resolution and tests
are retained. Final feature-head commit/tree, hosted run and artifact IDs belong
in the PR report, not in a self-referential evidence commit.

## Released tool, not a local substitute

| Identity | Approved value |
| --- | --- |
| Annotated tag | `v0.1.0` |
| Tag object | `14463739818eb4c78b93ad42ecc4a4077cbec2bc` |
| Source commit | `4ee95e8c95b8c7f54397a07e3e1c507783c115aa` |
| Source tree | `c5cff2cff52e595f71202bf97c513b7e0f46c918` |
| Wheel SHA-256 | `b0949aba6736515bf2ebe14fc7cc30c816a176257fc4524564285397b8aaf97d` |
| Sdist SHA-256 (not installed) | `b5114c9d186dc6d230f1d48c139739b32e83a037d7fe7e7516c46755916e854a` |
| Release provenance SHA-256 | `7d08f56d7566416009bcd0595ecaa186cc7701e1aa1c5e9d8349d6e601c1a269` |

The installer in `scripts/install_released_gnatdoc.py` downloads only the official
HTTPS wheel and provenance, checks redirect hosts, exact lengths, SHA-256 and all
41 member names, and compares all 35 installed package members to independently
fetched blobs from the approved Git tree before installation. The annotated tag
is unsigned: this is an object-identity check, not a signature-verification claim.
The entire fixed-hash archive authorizes distribution metadata as well.

Installation is non-editable, isolated, `--no-index --no-deps`. Optional Markdown
wheels are separately hash-pinned and retained; all installed package and metadata
bytes, launcher, CLI/module/distribution version and receipt are independently
rechecked before use. A receipt cannot authorize new bytes. This approach was
informed by Features DOC-011; Imgproc owns the constants, policy and code here.
Nothing was added to Alire dependencies. The new PR-only acquisition workflow
has no Pages permissions, publication steps or deployment capability.

## Fresh current-source results and limits

The toolchain remains Alire 2.1.1, GNAT 16.1.0, Alire GPRbuild 26.0.1
(executable 26.0.0), GNATdoc 26.0.0 (20260415). PATH's unrelated GNATdoc 27.0w
was not used. The pristine generator uses the existing public/leading switches
and project exclusions. Two clean isolated exact-main worktrees build against
normal indexed Core; their native outputs match each other and the unchanged
production generator's native invocation byte-for-byte.

* One public Imgproc package; **329** source-matched native declaration sections,
  including **193** subprograms. No private/internal units published.
* **1,596/1,596** meaningful documented elements, zero documentation warnings,
  zero warning/coverage deltas; both exception baselines remain empty.
* All six existing compiled examples execute successfully; no source changes.
* The released local-only probe independently matches every category, ordered
  overload label and distinct destination against the unchanged consumer matcher.
  The historical 66-label failure remains guarded by exact ordered comparisons
  and explicit label/category/destination/reorder mutation regression tests.
* Two fresh shared enhancements are byte-identical; repeat enhancement is
  byte-idempotent. Altering an operation destination is rejected by verification.
  Independent native anchors, snippet text and visible declaration text are
  compared separately from the tool's self-verification.

These are **partial** observations, not a complete current-source qualification.
The probe intentionally has no production Core mapping and no authored guides.
Its 350 local type links include two additional constant type marks compared with
legacy's 348: `Background_Label` → `Component_Label` and
`Default_Morphology_Border` → `Morphology_Border_Value`. Shared same-package hrefs
include the package filename; legacy uses same-page fragments. These differences
are observations requiring review, not blanket presentation approvals.

## Core boundary and minimal reproduction

Fresh Alire resolution selected **Core 0.5.0**, unpinned, origin
`git+https://github.com/zackboll/opencv_core_ada.git`, commit
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`. See `alire.lock`. An adjacent Core
checkout was not substituted into the build or source model.

Existing API links use `api/index.html?package=OpenCV` and
`?package=OpenCV.Core`; PR #80's examples additionally use genuine `?symbol=`
bookmarks. A fresh real Chromium probe, with **no request interception**, loads
the authentic HTTPS site, checks both package queries, and checks 14 symbol
queries plus their observed direct-fragment destinations and native headings.
The published Core review artifact was independently downloaded by immutable ID
`12238050173` (run `39361137547`, head
`aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d`); its ZIP SHA-256 matches API digest
`fd328d27efc3196b5861d11c73561c2d22451e2a0fcf2b6477d7c6e0f853cc37`.
That is a Core artifact observation, **not** an Imgproc candidate artifact claim.
All 14 observed hosted snippets also match genuine source-matched native sections
regenerated from indexed Core 0.5.0. This limited type-level equality does not
establish a complete version-compatible publication manifest. The Core native
probe emitted four missing-object-directory warnings; these are retained in its
observation report and it is not described as a qualified warning-free Core
native authority.

The released explicit external-type configuration rejects this minimal mapping:

```toml
[security]
external_hosts = ["zackboll.github.io"]
[external_types]
"OpenCV.Core.Mat" = "https://zackboll.github.io/opencv_core_ada/api/index.html?package=OpenCV.Core"
```

`inventory` exits 2: `external type OpenCV.Core.Mat requires explicit HTTPS page
and anchor`. Adding a query plus fragment is also outside its accepted contract.
The source-backed dependency manifest mode explicitly permits only reserved
`.invalid` offline-test publication. Neither mode may be bypassed, monkey-patched
or made to authorize production using the historical `core.invalid` manifest.

**This rejection is not by itself an upstream defect or proof of a hosting
failure.** The live site supports genuine fragments; independently approving a
compatible fragment mapping (and every intentional change from package-bookmark
semantics) may be possible. This PR has not established that production approval,
a complete source-backed production Core manifest, or a stable fallback policy.
Consequently all **586** existing API Core links remain absent from the partial
probe and the production migration gate remains closed. No invented anchors or
rewritten overload expectations are used to conceal this gap.

## Controls retained and work still required

Historical `gnatdoc008/`, `gnatdoc008c/`, TOML, runner, oracle and shadow workflow
remain unchanged. New evidence under `docs/evidence/` deliberately triggers the
existing historical applicability policy; its actual hosted result must be
reported independently. It is never current-source API qualification. None of
the 314/1,512/326/549 historical acceptance counts authorize these new results.

Production workflow, generator and all five legacy postprocessors remain
unchanged. No guide pipeline duplication or partial shared output is promoted.
Main-only Pages conditions and the `github-pages` environment are unchanged.
No release, tag, Alire publication, Pages deployment or automatic merge occurs.

Remaining gates include: production Core URL policy/manifest and version
compatibility approval; complete native-to-shared integrity and link census;
approved per-file semantic comparison; supported authored-page boundary with PR
#80 fidelity; complete shared browser/security mutation matrix; independently
qualified Pages inventory, prefix, script identities and uploaded artifact;
exact-final-head hosted qualification. Deployment and live acceptance remain
separate post-merge gates. This blocked checkpoint must not be described as
`READY_FOR_INDEPENDENT_REVIEW`.

## Reproduction

Use absolute task-owned directories outside the publication tree. `/tmp` was
inode-exhausted locally; set `TMPDIR` to a fresh directory on the home filesystem.
`initial-generation.log` retains that failed prerequisite attempt rather than
silently presenting it as a source failure.

```sh
python3 /absolute/imgproc/scripts/install_released_gnatdoc.py \
  --venv /absolute/new-release-venv --with-guides
python3 /absolute/imgproc/scripts/install_released_gnatdoc.py \
  --venv /absolute/new-release-venv --verify
# Supply native-first/ and native-second/ from clean public GNATdoc generations.
python3 /absolute/imgproc/scripts/qualify_released_gnatdoc.py \
  --venv /absolute/new-release-venv --workspace /absolute/fresh-probe-workspace
```

The preflight deliberately exits **2**, even when its local-only experiment
passes, because production adoption remains incomplete. It is not wired into
production as a weakened replacement gate. New acquisition tests and installed
asset/module/metadata/launcher/receipt tamper checks are separate from unchanged
legacy controls. Reports distinguish completed, failed and unperformed tests;
final-head hosted status belongs in the PR report.