# GNATdoc documentation campaign progress

Persistent resumption record for the IMGPROC-DOC campaign: bring the public
documentation of `opencv_imgproc_ada` to the standard of `opencv_core_ada`.
Documentation only: no production algorithm, C ABI, Ada API signature,
manifest dependency or runtime behavior changes. Never infer that a PR merged;
check GitHub before starting a dependent phase.

## Identity

- Campaign starting Imgproc `main`:
  `0bcbaa064a4683f553e449837025d01b07bb2b45` (merge of PR #51, verified as
  `origin/main` on 2026-10-13; no open PRs; no documentation branches).
- Core reference `main`: `7bcdc3a1b130b8f51f2c97ac9f014578a281e64e` (merge of
  Core PR #74, developer guides; Core documentation workflow succeeded on it
  and `https://zackboll.github.io/opencv_core_ada/` serves it).
- Isolated layout (mirrors CI's two-checkout layout):
  - `/home/zboll/git/opencv/imgproc-doc/imgproc` — worktree, branch
    `feature/imgproc-doc-001-gnatdoc-pages`.
  - `/home/zboll/git/opencv/imgproc-doc/core` — detached Core worktree at
    `7bcdc3a`, the `../core` pin target.
  The canonical worktree `/home/zboll/git/opencv/imgproc` and every existing
  branch and worktree were left untouched.
- Tools: Alire 2.1.1; GNAT 16.1.0; GPRbuild Alire 26.0.1 (executable 26.0.0
  (2026-04-15)); GNATdoc 26.0.0 (20260415) installed by
  `alr install gnatdoc_bin=26.0.0` into `.doc-tools/gnatdoc-26.0.0`; Python
  3.13.5; system OpenCV 4.10.0. The `gnatdoc` on `PATH` is GNAT Studio's
  27.0w and is never used.

## Gate 0 baseline

- AUnit on `0bcbaa0` with Core `7bcdc3a` and OpenCV 4.10.0:
  `alr -n -C tests run` — 1129 run, 1129 successful, 0 failed, 0 errors.
- Hosted CI: PR #51 head `ba49c4f` Cross-Platform Bridge CI succeeded (run
  38483281136). The push run on `0bcbaa0` (run 38484337334) was in progress
  at the single inspection; not polled again.
- GitHub Pages is not enabled for Imgproc (API 404, no environments).
- A stale `alire/alire.lock` with an empty solution made the first local
  `alr -n build` fail to find `opencv_core.gpr`; deleting the generated
  `alire/` and `config/` directories (untracked, ignored) fixed it.

## Phase status

| Phase | PR family | State |
| --- | --- | --- |
| 1 Infrastructure | IMGPROC-DOC-001 | Implemented and qualified locally; PR open for review |
| 2 Warnings and API comments | IMGPROC-DOC-002A..G | Not started (depends on DOC-001 merge) |
| 3 Theme, highlighting, type links | IMGPROC-DOC-003 | Not started |
| 4 Operation browser | IMGPROC-DOC-004 | Not started |
| 5 Guides and final audit | IMGPROC-DOC-005 | Not started |

Open documentation PRs: see the DOC-001 entry under "Checkpoint log".

## Feature-parity matrix (Core `7bcdc3a` versus Imgproc)

| Capability | Core source | Imgproc after DOC-001 |
| --- | --- | --- |
| Pinned generation with version gates | `scripts/generate_docs.sh` | Adapted; adds `../core` checkout gate |
| Public/internal GPR split | `docs_api.gpr`, `docs_internal.gpr` | Adapted; also excludes `opencv_core.gpr` via `OpenCV_Core'Project_Dir` |
| Partial-generation detection | `generate_docs.sh` grep | Same |
| Declaration-identity warning comparator | `scripts/compare_gnatdoc_warnings.py` (26 tests) | Adapted: identifier lists, 200-line spans, whole-identifier literals, `--fail-on-removed` ratchet (36 tests) |
| Warning baseline | empty (0) | 1,357 identities (target 0) |
| Site validator | `scripts/validate_docs.py` (195 packages, phrase probes) | New: exact file inventory, source-matched sections and overload profiles, link/anchor/active-content checks |
| Validator mutation tests | via feature-specific tests | `scripts/test_validate_docs.py` (synthetic + generated site, 35 tests) |
| Landing page | `docs/index.html` (themed) | `docs/index.html` (unstyled until DOC-003) |
| Compiled landing example | `docs/example.*`, local only | `docs/example.*`, compiled and run in CI |
| PR artifact, diagnostics, main-only Pages | `.github/workflows/documentation.yml` | Adapted to the two-checkout layout |
| Deterministic regeneration check | CI `diff -r` | Same |
| Theme and viewport metadata | `install_gnatdoc_theme.py`, `docs/assets/gnatdoc-theme.css`, `presentation.json` | DOC-003 |
| Ada highlighting | `highlight_gnatdoc_ada.py` | DOC-003 |
| Type cross-references | `link_gnatdoc_types.py`, `type-crossrefs.json` | DOC-003; needs Core-site package links |
| Generic-instance summaries | `enhance_gnatdoc_instances.py` | Not applicable: no public generic instantiations or tagged types |
| Searchable navigation | `enhance_gnatdoc_navigation.py`, `gnatdoc-navigation.js` (package-level) | DOC-004; operation-level design required |
| Browser qualification | `test_gnatdoc_*_browser.cjs` (external Playwright) | DOC-004 |
| Markdown guide renderer | `render_gnatdoc_guides.py`, `docs/requirements.txt` | DOC-005 |
| Developer guides | five `docs/*-guide.md` | DOC-005 |
| Overload-specific rendered-text checks | `validate_docs.py` tables | Seeded (Phase_Correlate); extended per DOC-002 group |

## Initial GNATdoc inventory (`0bcbaa0`, pinned tools)

One public package, `OpenCV.Image_Processing`; 3 HTML pages (landing, native
index, package page). No internal or Core package is published. 1,357
warnings, all in `opencv-image_processing.ads`:

| Message | Count |
| --- | ---: |
| parameter not documented | 747 |
| enumeration literal not documented | 256 |
| entity not documented | 157 |
| return value not documented | 115 |
| component not documented | 82 |

1,353 concern published declarations; 4 concern the private-part function
`Boundary_Equal` (entity, two parameters, return), which GNATdoc warns about
but does not publish. One entity warning is the undocumented package itself.

Declaration coverage, derived from the comparator's declaration index and the
mapped warning identities:

- 314 visible-part declarations, each with exactly one native section:
  184 subprograms (114 functions, 70 procedures), 99 types, 25 subtypes,
  6 constants. 142 distinct subprogram names; 28 are overloaded (70
  declarations).
- 159 declarations have a rendered leading comment; 155 have none (69 types,
  43 functions, 22 subtypes, 18 procedures, 3 constants).
- 36 declarations are warning-free (30 types, 3 subtypes, 3 constants). No
  subprogram is fully documented: 123 commented subprograms lack `@param`
  and/or `@return`. The specification contains no GNATdoc tags.
- 338 members are undocumented: 256 enumeration literals and 82 record
  components, including the discriminants `Corner_Dead_Zone.Enabled` and
  `Optional_Contour_Index.Present`.

Rendering defects found in the current comments (Phase 2 work):

- 18 of 177 visible-part comment blocks never render: trailing comments after
  their declaration (for example the 19-line Color_Conversion notes, YUV/Bayer
  output notes, the color-map version note) and section preambles separated
  from the next declaration by a blank line (drawing in-place semantics, Hough
  detection and evidence, segmentation, EMD and histogram banners).
- Trailing comments that directly precede the next declaration are attached
  to that declaration, e.g. the Phase_Correlate notes follow
  `Phase_Correlation_Result`; each such association must be reviewed.
- Six emphasis spans swallow `*` products in four sections: Blend_Linear
  (2), Match_Template (2), Refine_Corners_Subpixel and the first
  Update_Running_Average overload.

Warnings per functional group, derived from the actual declarations:

| Group | Declarations | Subprograms | Warnings |
| --- | ---: | ---: | ---: |
| A Filtering, kernels, derivatives, pyramids, blending | 51 | 29 | 194 |
| B Threshold, morphology, distance, flood fill, segmentation | 62 | 40 | 264 |
| C Color conversion, YUV, Bayer, color maps | 24 | 12 | 189 |
| D Geometry, resampling, remapping, subpixel patches | 24 | 16 | 102 |
| E Contours, connected components, drawing, text | 43 | 25 | 205 |
| F Histograms, accumulation, integral images, EMD | 60 | 41 | 209 |
| G Hough, generalized Hough, template matching | 34 | 13 | 131 |
| H Phase correlation, Hanning windows, corners | 16 | 8 | 58 |
| Package description and private `Boundary_Equal` | — | — | 5 |

## Current commands

```sh
cd /home/zboll/git/opencv/imgproc-doc/imgproc
python3 -m unittest discover -s scripts -p 'test_*.py' -v
sh scripts/generate_docs.sh
python3 -m unittest discover -s scripts -p 'test_validate_docs.py' -v
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
```

## Checkpoint log

### IMGPROC-DOC-001 — generator, diagnostics and Pages foundation

Branch `feature/imgproc-doc-001-gnatdoc-pages` from `0bcbaa0`.

Qualified locally on the branch content:

- Negative-first: the four new comparator shape tests failed against the
  verbatim Core comparator (`declaration signature did not terminate`,
  `ambiguous or missing component`, unmapped identifier-list object); the
  ratchet tests failed before `--fail-on-removed` existed; the validator test
  module failed before `validate_docs.py` existed.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 71 tests pass
  (36 comparator, 35 validator including 8 on the generated site).
- `sh scripts/generate_docs.sh`: 1,357 warnings, delta 0 added / 0 removed;
  validator: 1 public package, 3 HTML pages, 314 declaration sections (184
  subprograms); all local links and anchors resolve.
- Repeated generation is byte-identical (`diff -r`).
- `docs/example.adb` compiles with `-gnat2022 -gnata -gnatwa -Werror` and runs;
  a scratch copy with a false assertion fails, proving assertions are active;
  GNATformat 26.0.0 leaves it unchanged.
- actionlint 1.7.12 and ShellCheck 0.11.0 report nothing for the workflow and
  the script; `sh -n` passes.
- No file under `src/`, `cpp/`, `tests/`, `alire.toml` or the production GPR
  projects changed. AUnit evidence above (1129/1129) is for the unchanged
  library sources and was not rerun after the documentation-only changes.

PR state, hosted CI and the exact tested commit are recorded in the PR body
and in the next checkpoint entry once verified on GitHub.

Known limitations:

- Pages is not yet enabled; a repository administrator must select
  **Source: GitHub Actions** and restrict `github-pages` to `main` before the
  first main deployment can succeed.
- Documentation CI resolves Core from `main` at run time, like the
  cross-platform workflow, so the Core SHA is logged rather than pinned. Core
  sources affect name resolution only; Imgproc output is validated per run.
- The native index check reproduces the pinned GNATdoc 26.0.0 serialization;
  any generator change fails closed until requalified.

## Remaining roadmap

Each step starts from verified merged `main`, uses an isolated worktree,
rewrites the warning baseline it reduces, and stops at an open review PR.

1. **IMGPROC-DOC-002A** — automatic public-declaration coverage inventory
   (identity, kind, overload profile, documentation presence per declaration
   and member, checked in CI); package description; private `Boundary_Equal`
   comment; GNATdoc formula form research (`*` emphasis); group H and group D.
2. **IMGPROC-DOC-002B** — group A filtering.
3. **IMGPROC-DOC-002C** — group B threshold, morphology, distance,
   segmentation.
4. **IMGPROC-DOC-002D** — group C color (moves the unrendered Color_Conversion
   notes into `@enum` documentation).
5. **IMGPROC-DOC-002E** — group E contours, components, drawing.
6. **IMGPROC-DOC-002F** — group F histograms, accumulation, integral, EMD.
7. **IMGPROC-DOC-002G** — group G Hough and template matching; zero warnings;
   empty baseline.
8. **IMGPROC-DOC-003** — theme, viewport, Ada highlighting and verified type
   links: intra-page Imgproc types, and Core types (`OpenCV.Core.Mat`,
   `Mat_Array`, `Min_Max_Loc`; root `Size`, `Point`, `Scalar`, `Rect`,
   `Border_Kind`, `Float32_Value`, `Float64_Value`, `OpenCV_Error`, ...) linked
   at package level to the verified Core navigation URLs
   `https://zackboll.github.io/opencv_core_ada/api/index.html?package=OpenCV`
   and `...?package=OpenCV.Core` (HTTP 200 at campaign start). No
   declaration-level Core fragments.
9. **IMGPROC-DOC-004** — operation-level browser: source-backed category
   manifest, case-insensitive search over the 184 subprograms and types,
   overload identification, native anchors only, bookmarkable selection,
   no-JavaScript fallback, Playwright qualification at 1280/390 px in
   light/dark.
10. **IMGPROC-DOC-005** — five developer guides with compiled examples,
    landing-page integration, README pointer and final audit against the
    Phase 6 gate.

## Next executable task

Wait for independent review and hosted CI of the DOC-001 PR. Do not start
DOC-002A until that PR is verified merged on GitHub; then fetch `main`,
record its SHA, and branch `feature/imgproc-doc-002a-...` in a fresh
isolated worktree.
