# Task 052 — Version-conditional native masked SQDIFF_NORMED

## Amendment status

This document is the amended Task 052 implementation plan.

The original Task 052 plan was not present in this worktree, on
`origin/main` (`472b5718f1e0b14d217d347b1125bbde09cb0a44`, merge of PR #49),
or in any sibling imgproc worktree when this amendment was written. The gates
below are the gates already established by Tasks 049–051 for the masked
`Match_Template` family, restated so this amendment does not drop them. If a
fuller original Task 052 text is later supplied, reconcile this document
against it before implementation; do not silently drop a stricter original
gate.

This amendment changes production dispatch only. It does not authorize one
portable compatibility formula on every OpenCV version.

## Repository and starting gate

Repository: `zackboll/opencv_imgproc_ada`

Expected fetched `origin/main`:

`472b5718f1e0b14d217d347b1125bbde09cb0a44`

PR #49, portable masked cross-correlation, is merged.

Expected starting baseline: **1121/1121 AUnit PASS** (the count recorded for
the Task 051 feature before its final selector-regression commit). Re-count
the fresh baseline after fetching main. Do not treat this expected count as
a substitute for that run.

No open Imgproc PRs were found at amendment time. Re-check before creating
the branch.

Create:

- Branch: `feature/052-masked-normalized-squared-difference`
- Worktree: `/tmp/imgproc052-masked-sqdiff-normed`

Fetch main, confirm there is no conflicting open PR, and run a fresh baseline
before implementation. Preserve every existing worktree and branch, including
`/tmp/imgproc049-masked-template`, `/tmp/imgproc050-masked-ncc`, and
`/tmp/imgproc051-masked-ccorr`.

Check the post-merge workflow for PR #49 and record Linux, macOS, and Windows
separately. Do not claim Windows passed from Linux or macOS success. At Task
051 qualification time, Windows MSYS2 failed during package installation
before tests ran.

---

## Goal

Extend the existing masked `Match_Template` overload with:

`Normalized_Squared_Difference`

Corresponding OpenCV selector:

```cpp
cv::TM_SQDIFF_NORMED
```

Retain the existing masked methods:

- `Squared_Difference` (`cv::TM_SQDIFF`)
- `Cross_Correlation` (`cv::TM_CCORR`)
- `Normalized_Cross_Correlation` (`cv::TM_CCORR_NORMED`)

The masked default remains `Squared_Difference`.

The existing unmasked six-method overload is unchanged, including its direct
call of unmasked `cv::TM_SQDIFF_NORMED`.

The result remains a fresh owning Float32 C1 score map. For this method,
**lower scores are better**. Callers use `OpenCV.Core.Min_Max_Loc` and take
the minimum.

## Why the implementation is version-dependent

Exact `modules/imgproc/src/templmatch.cpp` was inspected at tags 4.1.0,
4.10.0, and 5.0.0 (local trees under `/tmp/ocv/src-*`).

OpenCV 4.1.0 `matchTemplateMask` implements only `CV_TM_SQDIFF` and
`CV_TM_CCORR_NORMED`. Every other selector, including
`CV_TM_SQDIFF_NORMED`, raises `cv::Error::StsNotImplemented`. Its UInt8
conversion also scales intensities by `1/255` and derives mask metadata from
the image type. The binding already avoids that conversion by passing
canonical Float32 snapshots.

OpenCV 4.10.0 and 5.0.0 `matchTemplateMask` implement masked
`TM_SQDIFF_NORMED` directly:

```text
templ2_mask2_sum = norm(template * mask, NORM_L2SQR)
image_square     = crossCorr(image^2, mask^2)
cross            = crossCorr(image, template * mask^2)
result           = image_square - 2 * cross + templ2_mask2_sum
result          /= sqrt(templ2_mask2_sum * image_square)
```

For a canonical binary mask, `mask^2 = mask`, so this is normalized masked
squared difference. The CPU `Mat` overload calls `matchTemplateMask` before
the unmasked implementation, so a mask argument does not fall through to
unmasked `TM_SQDIFF_NORMED` or to IPP `ipp_matchTemplate`.

A single portable fallback on 4.10.0 and 5.0.0 would discard that qualified
native operation. Production therefore dispatches by compile-time OpenCV
version, following `opencv_core_ada`'s `CV_VERSION_MAJOR` /
`CV_VERSION_MINOR` pattern (see `opencv_core_shim.cpp`).

There is one public Ada procedure and one C ABI entry point. Version
selection is entirely inside the C++ shim. Ada must not branch on the
OpenCV version.

## Mathematical contract

For binary mask `M`, template `T`, and image `I`, with sums over template
coordinates:

\[
R(x,y)=
\frac{\sum_i \left(M_i T_i - M_i I_{x,i}\right)^2}
{\sqrt{\left(\sum_i M_i T_i^2\right)
       \left(\sum_i M_i I_{x,i}^2\right)}}
\]

Equivalently, with `E_T = sum M T^2`, `E_I = sum M I^2`, and
`C = sum M T I`:

\[
R = (E_I - 2C + E_T) / \sqrt{E_T E_I}
\]

Each nonzero UInt8 mask byte has weight 1. Intensities stay in original
UInt8 units, 0..255. They are not divided by 255.

An ideal defined score is nonnegative. It is 0 at a perfect included-pixel
match and increases as the included squared error grows relative to the
included energies. Native rounding may place a finite score slightly below 0.
Do not clamp scores into `[0, 1]` or any other interval.

Do not confuse this method with `Squared_Difference` (unnormalized sum of
squares; lower is better, and an all-zero mask is defined) or with
`Normalized_Cross_Correlation` (cosine similarity; higher is better).

---

# Phase 1 — Exact-source research gate

Create:

`docs/masked-normalized-squared-difference-source-review.md`

Before writing the production branch, review and record, at exact tags
4.1.0, 4.10.0, and 5.0.0:

1. `matchTemplate` and `matchTemplateMask` in `templmatch.cpp`.
2. Unmasked `common_matchTemplate` for `TM_SQDIFF_NORMED`, including its
   integral-image window energy, `templSum2 / invArea`, `MAX(num, 0)`, and
   the denominator cutoff
   `diff2 <= min(0.5, 10 * FLT_EPSILON * wndSum2)`.
3. `crossCorr` block sizing (scale 4.5, minimum 256, optimal DFT size,
   Float64 DFT, row-step narrowing to `int`).
4. Whether masked `TM_SQDIFF_NORMED` can reach `ipp_matchTemplate` or
   `ippiSqrDistanceNorm`. The 4.10.0/5.0.0 masked function does not call
   those IPP entry points; re-verify rather than assuming a later edit.
5. OpenCV 4.1.0 `StsNotImplemented` for masked `TM_SQDIFF_NORMED`.
6. Divide-by-zero and nonfinite behavior of `result /=` when Scene energy
   is zero and when template energy is zero, separately on 4.10.0 and 5.0.0.
7. The 4.1.0 masked `TM_SQDIFF` formula
   (`crossCorr(image^2, mask) - 2 * crossCorr(image, template * mask^2) + templSum2`)
   and the unmasked `TM_SQDIFF_NORMED` normalization, which are the only
   native pieces available for the compatibility composition.
8. Any native signed-integer area, DFT size, or pointer step that the
   existing `fits` / `unmasked_fits` planner does not already cover for the
   new branch.

## Stop conditions

Stop and report the exact discrepancy, preserving the research notes, if any
of the following is true:

- 4.10.0 or 5.0.0 masked `TM_SQDIFF_NORMED` is not the formula above, or a
  mask argument does not select `matchTemplateMask`.
- The native 4.10.0/5.0.0 path performs an unguarded read, write, or signed
  overflow that the existing planner plus an ABI-safety comment cannot
  reject before the call.
- The 4.1.0 compatibility composition cannot be built from native OpenCV
  operations without a custom correlation kernel.
- 4.10.0 and 5.0.0 disagree with each other about whether a zero-Scene window
  is finite, and no single documented policy matches both without repairing
  positive-energy scores.
- Exact-version qualification cannot meet the predeclared tolerances below.

Do not replace the native 4.10.0/5.0.0 call with the 4.1.0 composition in
order to avoid a stop condition.

Do not implement a custom matching or DFT kernel.

---

# Phase 2 — Production dispatch

Keep the existing C ABI function:

```c
opencv_imgproc_match_template_masked(..., int32_t method)
```

Accept the existing selector `OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED`. Do not
hard-code Ada enumeration positions. Do not add a second entry point.

Both branches consume the same canonical snapshots already used by masked
SQDIFF, CCORR, and NCC:

```text
Image       owning Float32 C1 — original UInt8 intensities, unscaled
Template    owning Float32 C1 — original UInt8 intensities, unscaled
Binary mask owning Float32 C1 — exactly 0.0 or 1.0
```

Snapshots are taken from the logical Region only. Parent pixels never
participate. Inputs are not modified.

## Positive masked Template energy

Require at least one pixel where both the canonical Template sample and the
binary mask are nonzero. This is the same predicate already used for masked
NCC.

Reject the call otherwise. OpenCV 4.1.0 cannot form a masked normalized
denominator, and 4.10.0/5.0.0 divide by `sqrt(0 * E_I)`. An all-zero mask and
an all-zero included Template are therefore rejected for this method only.

`Squared_Difference` must continue to accept an all-zero mask and return its
already qualified zero map. CCORR and NCC behavior stays unchanged.

The scan may run once on the canonical snapshots inside the shim, before
either native call, so a raw C ABI caller cannot reach the divergent native
paths. Document it as ABI safety: bypassing it selects version-dependent
nonfinite or unimplemented results rather than the public rejection. Do not
also re-scan in Ada merely to duplicate the diagnostic.

## Shared zero Scene-energy policy

A Scene window may be zero at every included location while Template energy
is positive. The denominator is then zero while the numerator is `E_T > 0`.

The public contract, identical on every version, is a research proposal
until the sentinel proof in section 4 passes:

**exact Float32'Last (IEEE binary32 `0x7F7FFFFF`) at each
included-energy-zero window, and the native finite score everywhere else.**

This is not the masked NCC convention. NCC publishes exact +0.0 because a
zero included Scene is a defined zero cosine. Normalized squared difference
uses zero for a perfect match, so publishing +0.0 here would rank the worst
mathematical case as the best match. `Float32'Last` is a binding-defined
finite worst-match sentinel, not an OpenCV native numeric result and not
`+Inf`.

Do not change NCC, unnormalized SQDIFF, or CCORR. Those methods keep their
already qualified zero-energy behavior, including NCC's exact +0.0.

Apply a packed-bitset classifier, the existing
`opencv_imgproc_masked_template::normalize_zero_scene` or a same-proof
sibling that writes the sentinel instead of +0.0, only to this method's
completed local result, on every version, after the native call and before
move-publication. The classifier writes `Float32'Last` only where included
Scene support is empty. Do not point this method at the NCC writer: that
writer stores +0.0. Do not apply either writer to SQDIFF or CCORR.

The sentinel stays a proposal until qualification establishes ordering,
arithmetic safety, and identical behavior on 4.1.0, 4.10.0, and 5.0.0. If
that proof fails, stop with `ZERO_ENERGY_POLICY_NOT_ESTABLISHED`. Do not
pick another bit pattern silently.

Confirm during Phase 1 that the classifier's shift and padding proofs still
hold for this method. Record raw native bits before the write. If 4.10.0 or
5.0.0 already stores `0x7F7FFFFF` at those windows, the write is still
required so 4.1.0 cannot diverge.

## Mandatory sentinel proof

The sentinel is not production behavior until this proof is written into
`docs/masked-normalized-sqdiff-source-review.md` and the qualification gates
agree. Stopping here preserves the plan and the notes and does not open a
feature PR.

### Finite defined-score bound

For admitted UInt8 inputs and `n` included pixels:

```text
0 <= T,I <= 255
0 <= (T-I)^2 <= 65025
N <= 65025*n
```

When `E_T` and `E_I` are positive integer sums, `sqrt(E_T*E_I) >= 1`, so
`R <= 65025*n`. The existing `fits` planner already rejects areas above
signed `INT_MAX`, so `n <= INT_MAX` and:

```text
R <= 65025 * INT_MAX = 139674767073025
```

IEEE binary32 `Float32'Last` is approximately `3.40282347e38`, which is
larger than that bound by more than 24 orders of magnitude. Re-check the
bound against the actual native denominator (a Float64 square root of a
product, then a Float32 divide) before relying on it. The proof covers
mathematically defined scores only. It does not allow publishing a native
infinity or NaN from a positive-energy window.

### Minimum-score ordering

`Float32'Last` is strictly greater than every finite score inside the bound
above, so `OpenCV.Core.Min_Max_Loc` reports a defined score in preference
to the sentinel. A sentinel-versus-sentinel tie is a real tie. A defined
score that rounds to `Float32'Last` is outside the bound and is a stop
condition, not a fixture to delete.

### Exact zero classification

For canonical UInt8 snapshots and a binary mask, `E_I = 0` if and only if
every included Scene sample is exactly 0. Classify that with the packed
support bits. Do not infer mathematical zero from a rounded DFT correlation.

### Cost

Reuse the Task 050 packed-word classifier. Extra memory stays

```text
8 * (Scene_rows * (ceil(Scene_cols/64)+1) + ceil(Result_cols/64))
```

bytes, with the existing capacity and `ptrdiff_t` checks. Runtime stays
`O(Scene_area + Result_rows * Active_mask_pixels * ceil(Result_cols/64))`.
Do not add an unbounded per-output template scan.

### Same policy on every version

4.1.0, 4.10.0, and 5.0.0 publish `0x7F7FFFFF` at proven zero-Scene windows
and leave every other sample untouched. If the proof or the three-version
bit agreement fails, stop with `ZERO_ENERGY_POLICY_NOT_ESTABLISHED`.

## Reconciliation with the implementation task

This section records corrections applied on top of the earlier amendment.
Earlier sections that still mention a file name from the first amendment are
subordinate to this list:

- Worktree: `/tmp/imgproc052-masked-nsqdiff`
- Branch: `feature/052-masked-normalized-sqdiff`
- Expected fresh baseline: **1116/1116 AUnit PASS**, re-counted after fetch.
  The earlier 1121 figure was the pre-regression Task 051 count and is not
  the starting gate.
- Post-merge workflow
  https://github.com/zackboll/opencv_imgproc_ada/actions/runs/38321557698
  at `472b5718f1e0b14d217d347b1125bbde09cb0a44`: Linux success, macOS success,
  Windows failure while installing MSYS2 `mingw-w64-x86_64-libgcc` /
  `libstdc++` 16.2.0-5 over dependencies pinned to 16.2.0-4. Windows did not
  run tests and is not validated.
- Source review document:
  `docs/masked-normalized-sqdiff-source-review.md`
- Qualification files use the `masked_nsqdiff` stem.
- The 4.1.0 composition is specifically: native masked `TM_SQDIFF` for `N`;
  checked scalar accumulation for `E_T`; an owning squared Float32 Scene;
  native unmasked `TM_CCORR` of that squared Scene with the binary mask for
  sliding `E_I`; native multiply, square root, and divide. Task 051's
  unmasked-CCORR IPP `area*4` protection applies to that energy correlation.
  No custom sliding kernel.
- A positive-energy window whose native Scene-energy estimate is nonpositive,
  or whose published score is nonfinite, is a stop condition. Only exact
  mathematical zero Scene energy may be replaced by the sentinel.
- The corrected plan is committed with the implementation when every gate
  passes. An early research stop keeps the plan and findings and does not
  open a PR.

## OpenCV 4.10.0 and 5.0.0 — native call

```cpp
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
    cv::matchTemplate(
        image, patch, result, cv::TM_SQDIFF_NORMED, binary_mask);
#endif
```

Pass the binary Float32 mask. Do not zero the Template and call unmasked
`TM_SQDIFF_NORMED`: unmasked normalization uses the full template area and
unmasked window energy, which is a different formula wherever the mask is
not all ones.

Do not compose `TM_SQDIFF` plus a manual divide on these versions.

After the call returns, run the shared zero-Scene policy, then move-publish.

## OpenCV 4.1.0 — native composition

```cpp
#else
    /* compatibility: 4.1.0 matchTemplateMask has no TM_SQDIFF_NORMED */
```

Compose only from native OpenCV operations on the same snapshots:

1. Reject non-positive Template energy with the shared scan.
2. `E_T = cv::norm(patch.mul(binary_mask), cv::NORM_L2SQR)`.
   For binary `M` and the canonical 0..255 values this is the included sum
   of squares. Check the source of `cv::norm` at tag 4.1.0 and record
   whether it is a simple sum or a scaled reduction. If 4.1.0 `NORM_L2SQR`
   is not the mathematical sum of squares, use another native reduction that
   is (for example a native dot/sum of squares) and document the choice.
   Do not reimplement the reduction element-wise in the shim.
3. Compute the unnormalized masked squared-difference map with the native
   operation that 4.1.0 actually implements:

   ```cpp
   cv::matchTemplate(image, patch, diff, cv::TM_SQDIFF, binary_mask);
   ```

4. Compute included Scene energy with the same native correlation primitive
   4.1.0 uses internally (`crossCorr` of `image.mul(image)` with
   `binary_mask`). Call that OpenCV function, or the public operation that
   is a direct wrapper of it. Do not write a DFT loop.
5. Form the denominator with native `sqrt(E_T * scene_energy)` and native
   division of `diff` by that denominator.
6. Run the shared zero-Scene policy on the local result so mathematically
   zero denominators become exact `Float32'Last` (`0x7F7FFFFF`) instead of
   a native nonfinite value. Do not clamp any other sample. Do not publish
   +0.0: that bit pattern is a perfect match for this method and is reserved
   for masked NCC's different zero-Scene convention.
7. Move-publish only after success.

The 4.1.0 branch must also satisfy the IPP arithmetic bound already encoded
by `unmasked_fits` if, and only if, Phase 1 shows the selected native
correlation enters `ipp_matchTemplate` (signed `template.area() * 4`).
Masked `TM_SQDIFF` on 4.1.0 calls `crossCorr` directly and does not call
`ipp_matchTemplate`; do not copy the CCORR IPP check onto this branch
unless the review shows the call is reachable. Record the conclusion.

`#else` covers every compile older than 4.10, including 4.1.0. The
qualification set is 4.1.0, 4.10.0, and 5.0.0 only. Do not claim 4.6 or any
unpinned minor release was qualified. A build against an unpinned version
selects the preprocessor branch, but that is not qualification.

## What both branches share

1. Canonical unscaled Float32 image and template snapshots, and a binary
   Float32 mask.
2. The positive masked Template-energy requirement above.
3. The same zero Scene-energy policy above.
4. Existing input ownership (borrowed handles, no destruction or retention),
   logical Region isolation, `fits` / `span_fits` arithmetic preflight,
   local result storage, and move-publication only after success.
5. The same documented score meaning: normalized included squared
   difference, lower is better, native finite values retained, exact
   `Float32'Last` (`0x7F7FFFFF`) only on zero included Scene energy.

Failure leaves `Destination` unchanged. Exceptions stay inside the shim and
become the existing imgproc status model. Ada continues to raise
`OpenCV.OpenCV_Error` for contract violations and translated OpenCV
failures. No new public exception type.

---

# Phase 3 — Public Ada API

Extend the existing masked declaration's supported methods to exactly:

```text
Squared_Difference
Normalized_Squared_Difference
Cross_Correlation
Normalized_Cross_Correlation
```

```ada
procedure Match_Template
  (Source      : OpenCV.Core.Mat;
   Template    : OpenCV.Core.Mat;
   Mask        : OpenCV.Core.Mat;
   Destination : in out OpenCV.Core.Mat;
   Method      : Template_Matching_Method := Squared_Difference);
```

Reject `Correlation_Coefficient` and
`Normalized_Correlation_Coefficient` for the masked overload.

Input contract is unchanged: nonempty 2-D UInt8 C1 Source, Template, and
Mask; Mask dimensions equal Template; Template fits inside Source;
noncontinuous Regions and distinct headers that share storage are snapshotted;
identical input/output objects are rejected.

Result geometry is unchanged:

```text
Rows    = Source.Rows - Template.Rows + 1
Columns = Source.Columns - Template.Columns + 1
```

Document in the specification that `Normalized_Squared_Difference` chooses
the minimum, requires positive masked Template energy, defines zero included
Scene energy as exact `Float32'Last` (`0x7F7FFFFF`) once that sentinel is
qualified, and otherwise returns the native score without clamping. Masked
NCC keeps exact +0.0 for its own zero-Scene windows.

No new public type.

---

# Phase 4 — Safety audit, split by branch

Reuse `cpp/masked_template_layout_fits.hpp` and
`cpp/masked_ncc_zero_support.hpp`. Extend them only for a concrete overflow
the source review shows is reachable.

## Native 4.10.0 and 5.0.0

Audit `matchTemplateMask`'s `TM_SQDIFF` / `TM_SQDIFF_NORMED` arm:

- `norm(..., NORM_L2SQR)` on the masked template
- `image.mul(image)`, `mask.mul(mask)`, `template.mul(mask^2)`
- two `crossCorr` calls
- fused `result = -2 * cross + image_square + E_T`
- `sqrt(E_T * image_square)` and in-place division

Confirm the existing `fits` bounds cover both correlations, the Float32
snapshot bytes, DFT row-step narrowing, and tile counts. Masked dispatch
must not be described as covered by the unmasked IPP area check unless the
audit shows IPP is actually called.

## Compatibility 4.1.0

Audit separately:

- native masked `TM_SQDIFF` (the unnormalized map)
- the native Scene-energy correlation
- native `NORM_L2SQR` (or the replacement native reduction)
- native `sqrt` and division
- the IPP `area * 4` expression, and whether this branch can reach it

A check that exists only because the 4.1.0 composition performs it is not
added to the 4.10/5.0 native call.

Any semantic-looking C++ condition that remains (positive Template energy,
zero-Scene rewrite) needs an `// ABI safety:` comment naming the concrete
failure: version-dependent nonfinite results, unimplemented 4.1.0 selector,
or out-of-bounds access. "Defense in depth" is not sufficient.

No public semantic validation is otherwise duplicated in the shim.

---

# Phase 5 — Predeclared numerical tolerances

Write these limits into the qualification harness **before** running it and
before reading its output. Do not edit them after seeing results.

| Gate | Criterion | Failure action |
| --- | --- | --- |
| Template energy | Included sum of squares is positive, or the call is rejected | Reject must agree on every version |
| Zero Scene | Exact bits `0x7F7FFFFF` after the shared policy | Any other bit pattern fails |
| Oracle, finite positive Scene energy | Absolute error at most `max(1e-4, 4 * ULP(Float32(reference)))` | Report the sample; do not clamp or drop it |
| ULP | `nextafter` spacing of the rounded reference, not a Float64 approximation | Reported, not silently widened |
| Nonfinite | Any NaN or infinity at positive Scene energy fails | Never repaired |
| Minimum location | Oracle and implementation agree on unambiguous landmarks | A mismatch fails |
| Ranking margin | Report best and second-best scores and both margins | A rank change on a declared unambiguous fixture fails |
| Cross-version | Compare 4.1.0 fallback with native 4.10.0 and native 5.0.0 | See below |

The `1e-4` absolute floor is the same evaluation ceiling already fixed for
masked NCC. It is not permission to accept a wrong mask weight, a `1/255`
scale, or a swapped numerator. Relative and ULP extremes are reported even
when the absolute gate passes.

**Do not require identical Float32 bits between the 4.1.0 composition and
the 4.10.0/5.0.0 native operation.** They are different algorithms. The
native 4.10.0 and 5.0.0 results are the semantic control.

Cross-version comparison, for every score:

- maximum absolute difference
- maximum relative difference
- maximum ULP difference
- nonfinite class disagreement
- minimum location
- best-versus-second margin and any near-tie rank change

Predeclared cross-version acceptance, chosen before measurement because the
two algorithms share a Float64 DFT correlation but not the same
normalization rounding:

- absolute difference at most `1e-4`, and at most 8 ULPs of the native
  4.10.0 value, for finite positive-Scene scores
- exact `0x7F7FFFFF` agreement on zero-Scene scores
- identical minimum location on fixtures whose native 4.10.0 margin is
  greater than `1e-3` plus the 8-ULP allowance
- 4.10.0 versus 5.0.0 reported separately; a bit difference between those
  two native builds is a finding to explain, not an automatic license to
  retarget the control

If a fixture misses a gate, record `VERSION_CONSISTENCY_NOT_ESTABLISHED` or
`ORACLE_GATE_FAILED` with the raw bits. Do not widen a tolerance, delete the
fixture, clamp the score, or change the native call to force a pass.

---

# Phase 6 — Widened-integer oracle

One oracle serves both implementations. Suggested files:

```text
tests/masked_sqdiff_normed_consistency.cpp
tests/compare_masked_sqdiff_normed_outputs.py
tests/run_masked_sqdiff_normed_consistency.sh
tests/qualify_masked_sqdiff_normed_versions.sh
```

The corpus calls the production shim and the Core bridge, not a copied
formula and not `cv::matchTemplate` directly.

For each included pixel use integer values in 0..255. Accumulate with
checked unsigned 64-bit arithmetic:

```text
sum_tt = sum M * T * T
sum_ii = sum M * I * I
sum_ti = sum M * T * I
numer  = sum_ii - 2 * sum_ti + sum_tt
```

Each product `T*T`, `I*I`, and `T*I` is at most 65025. Reject the fixture
generator, not the binding, if any sum exceeds 2^53, so the integer value
is exactly representable as Float64. The reference score is the Float64
division of `numer` by `sqrt(sum_tt * sum_ii)`, then the nearest Float32,
using round-to-nearest-even. Compare that Float32 with the binding output
using the Phase 5 gate.

Zero `sum_ii` is not divided. The oracle's expected bits are `0x7F7FFFFF`
(`Float32'Last`), not `0x00000000`.

The harness records, per fixture and per version:

- which preprocessor branch was compiled (`native` or `compatibility`)
- `CV_VERSION` from the header actually included
- linked `cv::getVersionString()` and the loader path of `libopencv_imgproc`
- input, template, and mask geometry and active mask count
- score-map geometry
- every Float32 score as raw IEEE bits
- oracle bits, absolute error, and error in reference ULPs
- minimum location, minimum score, second-best score, and margin

Execute the binary that was compiled against that prefix. A 4.10 binary
must not be relinked and described as a 4.1 run.

Pinned prefixes, matching the existing NCC qualification layout:

```text
$HOME/.cache/video-task004/install-4.1.0
/usr                                          # distro 4.10 when that is the host
$HOME/.cache/video-task004/install-5.0.0
```

If `/usr` is not OpenCV 4.10.0, use the 4.10.0 prefix already used by
`tests/qualify_masked_ncc_versions.sh`. Record the prefix. Header major,
minor, and revision must equal the linked runtime version.

## Minimum corpus

Include at least:

- full mask, equal to unmasked included energy
- sparse mask and a single included pixel
- nonbinary UInt8 mask bytes, which become weights 0 or 1
- excluded corruption outside the mask, which must not change any score
- perfect match (ideal 0) and a clearly worse shift
- near-tied minima whose margin is reported
- a zero Scene window beside a positive window
- all-zero mask and all-zero included Template, both rejected
- high intensities near 255
- noncontinuous Regions and overlapping Source/Template storage
- one geometry that exercises a DFT block boundary already accepted by `fits`

---

# Phase 7 — AUnit tests

Add:

```text
tests/src/masked_sqdiff_normed_tests.ads
tests/src/masked_sqdiff_normed_tests.adb
```

Register the suite in the existing runner.

Cover:

1. Oracle agreement on a small exact map, within the predeclared gate.
2. Float32 C1 geometry.
3. Minimum location, not the maximum.
4. Binary mask semantics and excluded corruption.
5. Full and sparse masks.
6. Rejection of an all-zero mask and of a black included Template.
7. A zero Scene window stored as exact `Float32'Last` without changing the
   neighboring positive score. NCC's zero windows stay exact +0.0.
8. Region isolation and Source/Template/Mask immutability.
9. Fresh destination ownership; failure leaves the previous destination.
10. Rejection of the two unsupported masked methods.
11. Invalid depth, channel count, empty input, and size mismatch.
12. Recovery on the next valid call.

Rerun, and require green:

- `masked_template_tests` (masked SQDIFF)
- `masked_ncc_tests`
- `masked_ccorr_tests`
- `template_matching_tests` (unmasked six methods)

Do not change those assertions to make the new method pass.

---

# Phase 8 — Validation

Run a fresh baseline first and record the count.

Then run:

- focused new tests
- the four regression suites above
- the full AUnit suite
- `tests/qualify_masked_sqdiff_normed_versions.sh` on 4.1.0, 4.10.0, and 5.0.0
- the existing masked SQDIFF, NCC, and CCORR consistency scripts, to show
  those production paths still pass
- strict GCC and Clang C++17
- ASan/UBSan for the project shim and harness
- strict changed-Ada compilation
- GNATformat
- modified-Ada 79-column checks
- shell syntax checks

Strict C++:

```text
-std=c++17 -Wall -Wextra -Wpedantic -Werror
```

Strict Ada:

```text
-gnatwa -gnatwc -gnatwu -gnatwn
-gnatwe -gnatyM79 -Werror
```

Do not modify external AUnit sources to satisfy those flags.

Sanitizer instrumentation covers the compiled shim and harness. Prebuilt
OpenCV shared libraries are not instrumented by that build. Say so.

No SPARK campaign is required unless a SPARK-designated unit changes.

The qualification report must state which branch each prefix compiled
(`#if` native on 4.10.0 and 5.0.0, compatibility on 4.1.0) and the header
versus runtime version check. A run that only executed the compatibility
composition against 4.10.0 or 5.0.0 does not qualify those releases.

---

# Phase 9 — Documentation and hosted CI

Update `README.md` and the source-review document.

State explicitly:

- The version-dependent path exists because OpenCV 4.1.0 does not implement
  masked `TM_SQDIFF_NORMED` (`StsNotImplemented`), while 4.10.0 and 5.0.0 do.
- Qualified releases are exactly OpenCV 4.1.0, 4.10.0, and 5.0.0.
- 4.10.0 and 5.0.0 call native masked `cv::matchTemplate(..., TM_SQDIFF_NORMED, mask)`.
- 4.1.0 composes native masked `TM_SQDIFF`, native included Scene energy, and
  native normalization. It is not a hand-written matcher.
- Scores are normalized included squared differences in original intensity
  units. Lower is better. Zero included Scene energy is exact `Float32'Last`
  (`0x7F7FFFFF`) when the sentinel proof passes. NCC still uses exact +0.0
  for the same geometric case, because zero means "no correlation" there and
  "perfect match" here. Other scores are not clamped. Bit-identical agreement
  across the two algorithms is not claimed.
- Region isolation, borrowed input ownership, and failure atomicity match
  the existing masked overloads.

Extend the masked-method table:

| Method | Best match | Score semantics |
| --- | --- | --- |
| Squared_Difference | Minimum | Unnormalized included squared error |
| Normalized_Squared_Difference | Minimum | Included squared error normalized by template and scene energy |
| Cross_Correlation | Maximum | Unnormalized included intensity-product sum |
| Normalized_Cross_Correlation | Maximum | Included cosine similarity |

Add a short Ada example that matches with a mask and reads the minimum.

Add a bounded production regression of this method to Linux hosted CI, next
to the existing masked SQDIFF, NCC, and CCORR steps in
`.github/workflows/cross-platform.yml`. Keep the macOS and Windows workflow
policies. One hosted OpenCV is not three-version qualification.

---

# Git and PR workflow

Suggested commit:

`Add version-conditional masked normalized squared difference`

Suggested PR title:

**Add version-conditional masked normalized squared difference**

One normal feature commit where practical. Push normally. Do not amend,
rebase, or force-push.

Verify:

```text
local tested HEAD = fetched remote feature HEAD = PR head
```

Leave the PR open, non-draft, mergeable, unmerged, and with auto-merge
disabled. Inspect hosted CI once. Do not merge or release.

## Independent review gate

Stop after implementation, qualification, commit, push, and PR creation.

Report:

- Starting main SHA and fresh baseline count.
- Exact source findings for 4.1.0, 4.10.0, and 5.0.0, including why native
  masked `TM_SQDIFF_NORMED` is unavailable on 4.1.0.
- The preprocessor condition and the single C ABI entry point.
- Confirmation that 4.10.0 and 5.0.0 binaries executed the native call, and
  that the 4.1.0 binary executed the composition.
- Header and linked runtime versions and loader paths.
- Positive Template-energy rejection and the shared zero-Scene policy.
- Native-branch safety audit versus the 4.1.0 arithmetic and IPP audit.
- Oracle gate results and the predeclared tolerances, unchanged after the run.
- Every cross-version score difference, minimum location, and ranking margin.
- Explicit statement that Float32 bits were not required to match across the
  two algorithms, and whether any tolerance was missed.
- Focused and full AUnit counts, including preserved SQDIFF, CCORR, NCC, and
  unmasked suites.
- Strict compiler and sanitizer results, with the instrumentation boundary.
- Files changed.
- Final commit SHA, PR URL and state, and local/remote/PR head parity.
- Initial hosted CI status, per operating system.

Do not declare merge readiness before independent diff and exact-head CI
review.

## Preserved gates

This amendment keeps:

- the Phase 1 research gate and the stop conditions in that phase
- source review of `templmatch.cpp` at the three pinned tags before
  implementation
- the existing masked input, Region, ownership, and failure-atomicity tests
- regression of masked SQDIFF, masked CCORR, masked NCC, and unmasked
  template matching
- Linux hosted CI as a single-version regression, not as a substitute for
  the three-prefix qualification
- the independent PR-review gate above, with auto-merge left disabled

