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

The original feature review reported 4.1.0 NaN versus a finite 4.10.0
zero for Source `[0,0,9]`, Template `[6,6]`, Mask `[1,1]`. That historical
4.1.0 NaN finding is retained, but the reported cross-version distinction
was not reproduced. Corrective production-shim runs with the exact installed
libraries measured the following complete native maps on **all three**:

| Source | Window 0 bits/class | Window 1 bits/class |
| --- | --- | --- |
| `[0,0,8]` | `00000000` finite | `3f3504f3` finite |
| `[0,0,9]` | `ffc00000` NaN | `3f3504f3` finite |

The adjacent positive score is approximately 0.70710677, not zero.
`3f3504f3` and `3f3504f4` are adjacent representations near that value;
they are not one ULP above zero. Additional neighbor values 1, 2, 7, 10,
127 and 255, asymmetric sparse/full 2-D masks, Regions, multiple zeros,
and 63/64/65/127/129-column word-boundary fixtures are executable corpus
cases. Each run records every raw native bit, classification, exact integer
Scene energy, and finite native extrema alongside the binding map.

Across 1197 outputs per version, native maps contain 639 finite values,
547 NaNs and 11 infinities. All native nonfinite values occur at exact-zero
Scene energy; no positive-energy nonfinite result was observed. Native
classification is not inferred from a favorable fixture.

NCC still requires positive masked Template energy. Zero template energy
or an all-zero mask produces ones on 4.1.0 versus NaN on later versions,
so this case remains rejected. For Scene energy zero, the binding now
**defines exact Float32 +0.0 (`00000000`)**, irrespective of native output.
The complete native NCC map is computed first. Only proven zero-energy
samples are replaced. Every positive-energy score retains the native bits:
no clipping, decimal rounding, alternate NCC implementation, or arbitrary
nonfinite repair. SQDIFF is unchanged, including its all-zero-mask behavior.

## Exact support classifier and cost

The immutable owning logical Float32 snapshots contain exact UInt8 values
and binary weights. Scene energy is zero iff all included Scene values are
zero. Each Scene row is packed into uint64 nonzero-support words plus one
zero padding word. For each active mask offset `(u,v)`, shifted Scene row
`y+v` words are ORed into an output-row bitset. Bit `x` is therefore the OR
of exactly `Scene[y+v,x+u] != 0` at active mask positions. No reflection or
center anchor is involved. Only valid correlation coordinates are published;
Regions' parent pixels cannot enter the owning snapshots. Integer shifts
are exact; shift zero avoids undefined shifting by 64.

Additional storage is
`8 * (Scene_rows * (ceil(Scene_cols/64)+1) + ceil(Result_cols/64))` bytes.
Allocation counts are checked against vector capacity and ptrdiff_t before
multiplication. Existing geometry preflight bounds row sums, areas and
coordinates; the padding word makes every cross-word read valid. All
allocation and compatibility writes precede move-publication, so exceptions
leave Destination unchanged. There is no added public rejection policy.

Time is `O(Scene_area + Result_area + Result_rows * Mask_area +
Result_rows * Active_mask_pixels * ceil(Result_cols/64))`, about 64 outputs
per OR rather than one full template scan per output. Sparse masks benefit;
large dense masks still incur material overhead. A three-repeat unoptimized
local benchmark for 640x480 Scene and 31x31 mask measured 11.5--38.1 ms
for full support and 1.02--1.04 ms for two active pixels (concurrent validation
load, not a performance guarantee). Memory for that case is 42320 bytes.
This bounded packed-word cost is accepted for the compatibility rule; it is
not claimed to be asymptotically FFT-fast. The corpus tests the classifier
against exact uint64 energy sums, including shifts across word boundaries.

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
Proven zero-energy scores must have exact +0 bits. Positive-energy nonfinite
scores fail qualification and are reported, never repaired. Unambiguous maxima
must agree. Near-ties report
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

Corrective validation preserved the original 1110 AUnit tests: 1110/1110.
Focused NCC 9/9, masked SQDIFF 6/6 and unmasked matching 10/10 passed.
GNATformat, changed-Ada 79-column checks, forced strict changed-unit Ada
compilation, shell syntax and diff whitespace checks passed. GCC and Clang 19
C++17 strict builds and ASan/UBSan passed with project shim/harness sources
instrumented, not prebuilt OpenCV. Both compilers passed exact three-version
qualification: 38 cases, 1197 scores each, 966 exact +0 windows per version.
The integer oracle and unchanged-native-bit checks passed at every positive
energy output. No maximum or near-tie ranking changed. GNATprove was not run:
this corrective implementation is C++, and the Ada change is tests/comments.
No public semantic validation is duplicated in the C++ shim except the
positive masked-template-energy scan, retained because 4.1.0 and later
versions otherwise produce ones versus NaN. Hosted Linux runs one OpenCV
installation; it is not the three-version qualification above.

