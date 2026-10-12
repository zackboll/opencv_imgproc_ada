# Masked normalized correlation: source review

## Exact sources

Inspected `modules/imgproc/src/templmatch.cpp` at exact tags 4.1.0, 4.10.0,
and 5.0.0, plus `crossCorr` and the Core divide used by `result /=`.

All three versions expose masked `TM_CCORR_NORMED`. The CPU `Mat` path calls
`matchTemplateMask` before the unmasked implementation. This adapter passes
owning Float32 C1 snapshots, so OpenCL/UMat paths are not selected.

## Canonical snapshots

4.1.0 converts UInt8 image and template with scale `1/255` and derives mask
metadata from the image type. 4.10.0 and 5.0.0 convert UInt8 with scale one
and threshold the mask to 0/1. The production shim copies logical UInt8 rows
into three owning Float32 C1 matrices: intensities stay 0..255 and every
nonzero mask byte becomes exactly 1. No output rescaling is applied.

The native call is `cv::matchTemplate(image, patch, result, method, mask)`
with `TM_SQDIFF` or `TM_CCORR_NORMED` only.

## Normalization differences

4.1.0 builds template energy with `meanStdDev` on `template * mask`, multiplies
variance-plus-mean-square by template area, correlates `image^2` with
`mask^2` and `image` with `template * mask`, then applies `sqrt` and division
as separate operations. If that energy is below `DBL_EPSILON` it stores ones
and returns.

4.10.0 and 5.0.0 use `norm(template * mask, NORM_L2SQR)`, correlate
`image` with `template * mask^2`, then evaluate
`sqrt(energy * image_square_correlation)` and one division. For a binary mask
`mask^2 = mask`, so the formulas match when energy is positive. Floating-point
rounding does not. Zero template energy is not equivalent: later versions
divide by zero.

`crossCorr` still uses Float64 DFT blocks for Float32 inputs, block scale 4.5,
minimum block 256, optimal DFT sizes, and inverse scaling. 4.1.0 passes an
explicit correlation size. DFT row step is narrowed to `int` for HAL.

## Zero-energy policy

A recheck of the installed libraries, using the same UInt8-to-unscaled-Float32
snapshots as the shim, showed:

- a Scene window whose every included sample is zero, with a positive
  two-pixel template and a full mask: exact Float32 zero (`0x00000000`) on
  4.1.0, 4.10.0, and 5.0.0;
- an adjacent window with one zero and one positive included sample: exact
  zero on 4.1.0 and one ULP above zero (`0x3f3504f3` versus `0x3f3504f4`)
  on 4.10.0 and 5.0.0;
- zero template energy or an all-zero mask: ones on 4.1.0 and NaN on 4.10.0
  and 5.0.0.

An earlier direct probe that passed a different mask shape produced
`+infinity` on some builds. That result is not stable for the canonical
snapshot inputs, so the binding does not promise infinity and does not replace
native scores. Fully zero windows in the qualified corpus are exact zeros.
Changing the excluded neighbor from 8 to 9 makes 4.1.0 return NaN for the
zero window while 4.10.0 stays finite. The binding does not repair that
native difference. The qualified and AUnit zero-window fixture uses neighbor
8, where all three versions return exact zero.

NCC therefore requires at least one canonical snapshot pixel where both the
Float32 template sample and the binary mask are nonzero. The check runs after
snapshot construction so a raw C caller cannot reach the divergent ones/NaN
paths. It is numerical portability, not a ban on black images. Fully
zero-energy Scene windows are left as the native finite score. No sentinel
or infinity substitution is applied. Mixed windows must satisfy the same
absolute ceiling. SQDIFF still accepts an all-zero mask and returns zeros.

## Safety

`masked_template_layout_fits.hpp` already rejects signed area overflow,
Float32 snapshot overflow, DFT row-byte narrowing, and tile-count overflow
for the shared `crossCorr` planner. NCC adds the same correlations, plus
`mul`, `sqrt`, and Float32 division inside OpenCV. No extra geometry term was
required. Identical input/output objects are rejected; distinct headers that
share storage are snapshotted first. The result is move-published only after
success. Exceptions stay inside the shim.

The positive-energy scan is the only semantic-looking C++ condition. It is
retained because bypassing it selects version-dependent ones versus NaN, and
the comment in the shim records that ABI reason. No other public semantic
validation is duplicated in the C++ shim.

## Numerical policy

The absolute ceiling `1e-4` was fixed before comparing versions. It is an
evaluation ceiling for ordinary finite scores, not permission to accept every
difference inside it. Relative and ULP extremes are reported separately.
`+infinity` bits must agree. Unambiguous maxima must agree. Near-ties report
margins and any ranking change. The tolerance is not widened after inspection.

Qualification commands, from the repository root:

```sh
sh tests/qualify_masked_ncc_versions.sh \
  "$HOME/.cache/video-task004/install-4.1.0" /usr \
  "$HOME/.cache/video-task004/install-5.0.0"
```

Hosted Linux runs one production-shim corpus against its installed OpenCV. It
is not three-version qualification. Sanitizers cover the compiled shims and
harness; prebuilt OpenCV libraries are not sanitizer-instrumented.

Measured GCC results, after the ceiling was fixed:

- 4.1.0 versus 4.10.0: max absolute `1.1920928955078125e-7`, max relative
  `1.4562728589330325e-7`, max ULP 2, no nonfinite values, no location or
  ranking changes.
- 4.1.0 versus 5.0.0: the same absolute, relative, and ULP maxima.
- 4.10.0 versus 5.0.0: exact agreement, including bits.

The near-tie fixture keeps its maximum at `(0, 0)` on every version. Its
best-versus-second margin is `1.8483400344848633e-4`. No tolerance was
widened. The widened integer oracle accepted every finite score within
`1e-4`.

## Local validation

Starting main: `0bd1964d63f4c96e5f81ca6376f2bf085235a51b`.
Post-merge workflow
https://github.com/zackboll/opencv_imgproc_ada/actions/runs/38190743261
completed with Linux and macOS success. Windows failed while installing
MSYS2 packages (`libgcc`/`libstdc++` dependency conflict) before the tests
ran. That is not evidence that Windows tests passed.

Fresh baseline and final suite counts are recorded after the local runs.
No public semantic validation is duplicated in the C++ shim except the
positive masked-template-energy scan, retained because 4.1.0 and later
versions otherwise produce ones versus NaN. Hosted Linux runs one OpenCV
installation; it is not the three-version qualification above.

