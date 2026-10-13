# Masked normalized squared difference

## Why the path depends on the OpenCV version

`matchTemplateMask` at tag 4.1.0 implements only `TM_SQDIFF` and
`TM_CCORR_NORMED`. `TM_SQDIFF_NORMED` raises `StsNotImplemented`.

Tags 4.10.0 and 5.0.0 implement it as masked squared error divided by
`sqrt(template energy * scene energy)`. The CPU `Mat` overload selects that
function before the unmasked implementation, so a mask argument does not fall
through to IPP.

The shim therefore uses one entry point and this compile-time gate:

```cpp
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
    cv::matchTemplate(image, patch, result, cv::TM_SQDIFF_NORMED, binary_mask);
#else
    /* native masked TM_SQDIFF, native unmasked TM_CCORR of image^2, native divide */
#endif
```

Qualified releases are exactly 4.1.0 (compatibility), 4.10.0 (native), and
5.0.0 (native). Header `CV_VERSION` matched `cv::getVersionString()` on each
run, and each binary loaded that prefix's `libopencv_imgproc`.

## Shared contract

Both branches use the existing unscaled Float32 snapshots and a binary mask.
Positive masked template energy is required. Zero included Scene energy
publishes `Float32'Last` (`0x7F7FFFFF`), not NCC's +0.0. NCC is unchanged.

For admitted UInt8 data, `n` included pixels, and positive energies:

```text
R <= 65025 * n <= 65025 * INT_MAX = 139674767073025
```

`Float32'Last` is about `3.40e38`, so it sorts after every defined score.
The packed-bit classifier writes it only where every included Scene sample
is exactly zero. Positive-energy nonfinite scores are not repaired.

## Qualification

Predeclared gates, fixed before the run: oracle error at most
`max(1e-4, 4 ULP)`, and cross-version absolute difference at most `1e-4`
with at most 8 ULPs. The six-fixture corpus (46 scores) met a stronger
result: 4.1.0, 4.10.0, and 5.0.0 published identical score bits, identical
minima, and the same sentinel. That identity is a measurement of this
corpus, not a promise for every DFT size.

No public semantic validation is duplicated in the C++ shim except the
positive-energy scan and the zero-Scene rewrite. Both are ABI safety: the
first avoids version-dependent divide-by-zero or `StsNotImplemented`, and
the second replaces a native nonfinite payload with one rankable value.
