# Generalized Hough Guil source review

Reviewed `modules/imgproc/src/generalized_hough.cpp` at the pinned tags:

- OpenCV 4.1.0 and 4.10.0: byte-identical Guil implementation.
- OpenCV 5.0.0: the only Guil difference is that the feature-buffer lambda
  captures `maxBufferSize` by value instead of `this`. Behavior is unchanged.

Shared Canny and Sobel preprocessing is the same path already reviewed for
Ballard. This note does not reopen that scratch-buffer lifetime study.

## Algorithm stages

`createGeneralizedHoughGuil` constructs `GeneralizedHoughGuilImpl`. The shim
sets every parameter explicitly:

- levels = 360, xi = 90 degrees, angle epsilon = 1 degree
- dp = 1, minimum distance = 1, maximum feature buffer = 1000
- public Canny, angle, scale, and three vote thresholds

`setTemplate` runs Canny and Float32 Sobel, then `buildFeatureList`. The
template center passed by the shim is `(cols / 2, rows / 2)`. `detect` repeats
edge extraction on the scene, then `calcOrientation`, `calcScale`, and
`calcPosition`. `minDist = 1` skips `filterMinDist`.

`getContourPoints` reserves `edges.size().area()`. In all three versions
`Size_<int>::area` multiplies signed width and height. The planner therefore
requires `rows * cols <= INT_MAX` before that call.

`buildFeatureList` keeps a pair only when `angleEq(theta1 - theta2, xi, 1)`.
With xi fixed at 90, a same-point pair has orientation difference 0.
`clampAngle(0 - 90)` is 270, and `fabs(270) <= 1` is false, so that pair is
not selected. Distinct points can still produce a zero `norm` only if both
positions compare equal, which this integer contour lattice does not do for
distinct points. The scale stage divides `imF.d12 / templF.d12`; the selection
condition, not an extra Ada epsilon, is what excludes the same-point zero.

Each of 361 orientation bins stores at most 1000 features. One histogram stage
therefore performs at most `361 * 1000 * 1000 = 361000000` increments. That
fits signed Int32, and no stage sums those capped bin counts into one wider
accumulator. Position voting uses the same per-bin cap, so Ballard's tighter
per-cell edge bound is not reused; the Guil cell bound is this pair product.

## Histogram preflight

Angle bins follow the native reciprocal product, not direct division. One extra bin is allocated.
`cvRound(span * (1 / step))` can land on that extra bin when the value
equals the maximum. The planner requires finite parameters, a positive
reciprocal, a `cvCeil(span * (1 / step))` result in `1 .. INT_MAX - 1`, and a
rounded maximum index no larger than that extra bin. Scale uses the same
product. Angle must
also satisfy the native assert `0 <= min < max <= 360` and `0 < step < 360`.
Scale must satisfy `0 < min < max` and `step > 0`.

`span / step` is not equivalent. For minimum 0.1, maximum 0.8, and step 0.1,
`(0.8 - 0.1) * (1 / 0.1)` is `7.000000000000000888` and `cvCeil` returns 8.
Direct division is exactly 7. Scale 0.5..0.6 step 0.2 is 0.5 either way, so
`cvCeil` returns 1. The first planner checked parameters with the native
product but recomputed output limits with direct division. `histogram_bins`
is now the only range calculation. `plan` returns both integer counts, and
histogram room, candidate bounds, signed narrowing, byte widths, and the
shim's post-detection count check all reuse those counts.

Position uses `cvRound` after a coordinate that the source accepts only when
strictly below the histogram dimension. With dp = 1 the rounded coordinate is
therefore at most `dimension - 1`, which fits signed int whenever the image
dimension does. The histogram has a one-cell halo (`rows + 2`, `cols + 2`);
its byte size is bounded before allocation.

## Output bound

Each accepted angle and scale can emit one local-maximum peak per spatial
cell. The count is the product of the two native histogram counts and the
scene area. Widened int64 division precedes every multiplication, so the
product and its 16-byte and 12-byte copies are proven before overflow. The
signed narrowing limit is `INT_MAX / 16` (134,217,728).

A full 0..360 by 1 degree and 0.5..2.0 by 0.05 search has 360 and 30 bins.
On a 48×40 template, without allocating either image:

- 4096×4096 is rejected. Its candidate count is 181,193,932,800, or 1350
  times 134,217,728.
- 4096×3 is accepted (132,710,400 candidates).
- 4096×4 is rejected (176,947,200 candidates).

A narrower window still admits a larger scene. This is output safety, not a
scene-size cap.

## Publication

The shim borrows Core Mat handles, rejects identical input/output objects,
copies logical UInt8 rows into private continuous snapshots, and creates a
fresh detector. Both results are validated, then published with nonthrowing
`cv::swap` of the two headers. Failure leaves the caller's destination objects
unchanged. Borrowed inputs are not retained.

No public semantic validation is duplicated merely for friendlier messages.
Retained ABI guards are nonempty 2-D UInt8 C1 storage, representable native
arithmetic, distinct output objects, and finite nonnegative decoded outputs.

## Measured consistency

`tests/qualify_guil_versions.sh` ran the production shim on exact 4.1.0,
4.10.0, and 5.0.0 libraries. All 15 synthetic fixtures, including empty
results, compared with exact equality of centers, scales, degree angles, and
all three vote counts. Linux CI runs the single installed OpenCV corpus under
ASan/UBSan; it does not itself perform the three-version comparison.
