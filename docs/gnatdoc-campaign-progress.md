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

## Execution model (from 2026-10-13, user-authorized)

The user replaced "stop at each merge" with a stack of review PRs: each
phase branches from the previous phase's verified head, its PR targets the
previous phase's branch, and work continues immediately after the PR opens.
No PR is merged, auto-merge stays off, nothing is force-pushed, and Pages is
never deployed from a feature branch. Each PR body records its parent PR,
parent commit and phase-specific delta. If an ancestor merges, verify GitHub
state and reconcile downstream bases without rewriting published history.

Comment groups B to G were drafted in parallel by documentation agents in
isolated worktrees (`/home/zboll/git/opencv/imgproc-doc/agent-*`) from the
DOC-002A foundation commit `f576f4a`, each restricted to its declaration
list and verified with the build, GNATdoc, coverage, GNATformat and
comment-only checks; each draft is then reviewed, applied on its stacked
branch, regenerated and qualified there.

## Phase status

| Phase | Branch | PR (base) | State |
| --- | --- | --- | --- |
| DOC-001 infrastructure | `feature/imgproc-doc-001-gnatdoc-pages` | #52 (`main`) | Open; hosted CI success on `7e1279d` |
| DOC-002A coverage foundation, groups D and H | `feature/imgproc-doc-002a-coverage-foundation` | #53 (DOC-001 branch) | Open; head `859e66a` (tested `6a72ef3`) |
| DOC-002B group A filtering | `feature/imgproc-doc-002b-filtering` | #54 (DOC-002A branch) | Open; head `4d6f7f0` |
| DOC-002C group B morphology | `feature/imgproc-doc-002c-morphology` | #55 (DOC-002B branch) | Open; head `8c3feb6` |
| DOC-002D group C color | `feature/imgproc-doc-002d-color` | #56 (DOC-002C branch) | Open; head `bba9821` |
| DOC-002E group E contours and drawing | `feature/imgproc-doc-002e-contours` | #57 (DOC-002D branch) | Open; head `a465211` |
| DOC-002F group F histograms | `feature/imgproc-doc-002f-histograms` | DOC-002E branch | Qualified locally |
| DOC-002G group G Hough and matching | `feature/imgproc-doc-002g-matching` | stacked | Draft reviewed; next |
| DOC-003 theme, highlighting, type links | `feature/imgproc-doc-003-presentation` | stacked | Tooling staged locally |
| DOC-004 operation browser | `feature/imgproc-doc-004-navigation` | stacked | Tooling staged locally |
| DOC-005 guides and final audit | `feature/imgproc-doc-005-guides` | stacked | Not started |

GitHub Pages remains disabled (external administrator action).

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

### IMGPROC-DOC-002A — coverage foundation, groups D and H

Branch `feature/imgproc-doc-002a-coverage-foundation` from DOC-001 head
`7e1279d`; PR targets `feature/imgproc-doc-001-gnatdoc-pages`.

- `scripts/check_doc_coverage.py` (+ 21 tests): source-derived inventory of
  1,512 items (package, 314 declarations, 745 parameters, 114 returns, 256
  literals, 82 components/discriminants); non-trivial rendered text per item;
  attachment of every visible-part comment block; ratchet baseline. Its
  real-site test failed first on the 22 attachment defects it was written
  to catch (18 detached blocks, 4 emphasis-mangled formulas).
- `scripts/check_comment_only.py` (+ 6 tests): declarations unchanged.
- GNATdoc 26.0.0 findings (scratch experiments): code spans and indented
  blocks render `*` literally, `\*` is not an escape; tag text continues over
  lines; a package description may be the first block inside the package
  (needed because GNATformat separates a leading comment from `package`);
  `@exception OpenCV.OpenCV_Error` is split at the dot, so use
  `@exception OpenCV_Error`; long enumeration snippets are elided with `…`.
- Repairs: package description (conventions plus the drawing, Hough and
  segmentation preambles), the 19-line Color_Conversion notes and 11 YUV,
  Bayer and color-map notes now lead their declarations, banners removed,
  four formulas use code spans or an indented block, private
  `Boundary_Equal` documented.
- Groups D and H fully documented (40 declarations; agent draft reviewed and
  spot-checked against the body, shim and source reviews). Corrections: the
  warps and Resize write Destination directly (OpenCV may reuse its storage),
  not "always replace"; Remap and Warp_Polar publish privately; Linear_Exact
  is rejected by warps, remaps and Warp_Polar; nearest-only fixed maps round
  rather than truncate; the garbled Refine_Corners_Subpixel sentence was
  rewritten (empty sources rejected; Float32 sources scanned for finiteness
  even with no corners).
- Warnings 1,357 -> 1,184; coverage 159 -> 328 of 1,512 items.

### IMGPROC-DOC-002B — group A filtering

Branch `feature/imgproc-doc-002b-filtering` from DOC-002A head `859e66a`.

- 51 filtering, kernel, derivative, edge, pyramid and blending declarations
  documented (agent draft reviewed and spot-checked). Each Destination states
  its model: direct native output for the native filters, Canny, Sobel,
  Scharr, Laplacian, Pyramid_Down and the natural Pyramid_Up; private
  publication for the explicit-size Pyramid_Up and Pyramid_Mean_Shift_Filter.
- Corrections: Gaussian_Blur, Laplacian and Canny_Edges write Destination
  directly (not "replaced"); Sobel in place only with Same_Depth (Sobel,
  Scharr and Laplacian have no alias check); Get_Gabor_Kernel's
  self-contradicting reversal sentence; Squared_Box_Mode had no comment of
  its own (its trailing comment documented Squared_Box_Filter).
- The package-wide Region convention was too strong: native filters pass a
  Region to OpenCV as a submatrix without BORDER_ISOLATED, so border
  extrapolation may read parent pixels. The convention now says so, and
  isolation is stated per operation where it exists.
- Checker fix (negative-first test): list markers inside an indented code
  block are verbatim, not stripped.
- Warnings 1,184 -> 990; coverage 328 -> 522 of 1,512 items.

### IMGPROC-DOC-002C — group B thresholding, morphology, segmentation

Branch `feature/imgproc-doc-002c-morphology` from DOC-002B head `4d6f7f0`;
documentation commit `86e7c64`.

- 62 declarations documented: thresholds, structuring elements and every
  Erode/Dilate/Apply_Morphology/Hit_Or_Miss overload, distance transforms,
  flood fill, Watershed and GrabCut. Direct native output for thresholds and
  morphology; fresh owning results for distance transforms and structuring
  elements; in-place mutation for Flood_Fill images and masks and Watershed
  markers; GrabCut refinement works on private clones committed on success.
- Corrections: Constant_Border uses Border_Value (OpenCV's neutral value
  only by default); misattached custom-kernel, anchor, GrabCut model and
  structuring-element comments redistributed; Apply_Adaptive_Threshold also
  requires a finite Bias.
- Warnings 990 -> 726; coverage 522 -> 786 of 1,512 items.

### IMGPROC-DOC-002D — group C color

Branch `feature/imgproc-doc-002d-color` from DOC-002C head `8c3feb6`.

- 24 declarations documented. Color_Conversion keeps the recovered notes and
  documents every one of its 86 literals (source and destination layout,
  depth restriction) from `Required_Color_Channels`, `Color_Depth_Policy` and
  the shim's conversion table. Convert_Color and both Apply_Color_Map
  overloads publish a private result; YUV and Bayer functions return fresh
  owning storage from independent snapshots.
- Corrections: the Bayer bilinear fallback below 8 pixels applies to
  Variable_Number_Of_Gradients only (4.1/4.10 decode every pattern and order
  as BGGR/BGR there, 5.0 honors them); BGR565/BGR555 and premultiplied
  selectors accept UInt8 only; Ada and the shim both enforce even YUV422
  widths.
- Unverified by tests (documented from names and OpenCV conventions): XYZ,
  YCrCb, YUV, Lab and Luv channel order; 16 of 20 color maps described only
  by their native constant.
- Warnings 726 -> 545; coverage 786 -> 967 of 1,512 items.

### IMGPROC-DOC-002E — group E contours, components, drawing

Branch `feature/imgproc-doc-002e-contours` from DOC-002D head `bba9821`.

- 43 declarations documented, including both Draw_Contours and Fill_Contours
  overloads, Optional_Contour_Index's discriminant and variant component,
  every drawing primitive and the text metrics.
- Corrections: Connected_Components_With_Stats writes Labels as a direct
  native output (`_labels.create` reuses Int32 C1 storage of Source's size),
  not "always replaced"; Text_Metrics baseline is measured from the
  bottom-most text point up to the baseline; Measure_Text and Draw_Text
  validate Font_Scale before treating empty text as a no-op; shim
  text-geometry limits documented (Font_Scale at most about 15.26).
- Unverified: ellipse rotation direction beyond the 90-degree test;
  retrieval/approximation literal semantics beyond the tested modes.
- Warnings 545 -> 340; coverage 967 -> 1,172 of 1,512 items.

### IMGPROC-DOC-002F — group F histograms, accumulation, integral, EMD

Branch `feature/imgproc-doc-002f-histograms` from DOC-002E head `a465211`.

- 60 declarations documented: image accumulation and running averages,
  integral images, Equalize_Histogram and CLAHE (direct native output), the
  dense and nonuniform histogram types, constructors and accessors, every
  Calculate/Compare/Back_Project/Accumulate overload and Earth Mover's
  Distance (fresh owning results published only after success).
- Corrections: EMD signatures always need equal column counts, including the
  explicit-Cost overloads; Back_Project also rejects
  `abs Scale > Float32_Value'Last`; the Equalize_Histogram example renders as
  a code block. CLAHE documents its actual Region behavior (see findings).
- Unverified: native zero-bin handling in histogram comparison.
- Warnings 340 -> 131; coverage 1,172 -> 1,381 of 1,512 items.

## Findings for the maintainers (not changed: outside documentation scope)

- CLAHE (shim `opencv_imgproc_clahe`): the isolating clone is taken only for
  a same-object or non-continuous Source, so a continuous Region (for
  example full-width rows) is passed as a submatrix and Reflect_101 padding
  can read parent pixels; an agent probe on OpenCV 4.10 differed from a
  clone by up to 14. The clip-limit guard assumes 65536 histogram bins, but
  UInt8 uses 256, so a large finite Clip_Limit can still overflow the
  native int conversion. Documented as implemented.
- README "Connected components" says Labels is always rebound; the shim
  passes it to OpenCV directly, which reuses matching storage (DOC-002E).
- A default-initialized Histogram_Nonuniform_Dimension (no edges) passed to
  the single-source Calculate_Nonuniform_Histogram appears to raise
  Constraint_Error from `Natural (0) - 1` rather than OpenCV_Error
  (DOC-002F agent reading of the body; untested).
- Further items are listed in the checkpoints of the phases that found them.

## Remaining roadmap

Each step branches from the previous phase's verified head, rewrites the
baselines it reduces, and opens a stacked review PR; work then continues.

1. **IMGPROC-DOC-002A** — done (see checkpoint).
2. **IMGPROC-DOC-002B** — done (see checkpoint).
3. **IMGPROC-DOC-002C** — done (see checkpoint).
4. **IMGPROC-DOC-002D** — done (see checkpoint).
5. **IMGPROC-DOC-002E** — done (see checkpoint).
6. **IMGPROC-DOC-002F** — done (see checkpoint).
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

Apply the reviewed group G draft (`agent-g`, diff against `f576f4a`) with
`git apply -3` on `feature/imgproc-doc-002g-matching` from the DOC-002F
head, regenerate both baselines (both become empty), qualify and open the
stacked PR; then DOC-003 (staged tooling in
`/home/zboll/git/opencv/imgproc-doc/dev-003`, local commits), DOC-004 and
DOC-005.
