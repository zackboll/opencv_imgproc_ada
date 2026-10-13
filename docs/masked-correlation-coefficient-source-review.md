# Task 053 — Masked correlation coefficient source review

Base: `origin/main` `cc1e7a5c4c642ee8029d0de054a49035d3d844de`.
Sources inspected: `modules/imgproc/src/templmatch.cpp` at exact commits
4.1.0 `371bba8f`, 4.10.0 `71d3237a`, 5.0.0 `40738fb1` (local checkouts under
`/tmp/ocv/src-*`).

## Source findings

1. **4.1.0** `matchTemplateMask` (line 765) handles only SQDIFF and
   CCORR_NORMED; every other method reaches `CV_Error(StsNotImplemented)`.
   Masked CCOEFF throws. Verified at runtime by the probe.
2. **4.10.0 / 5.0.0** implement masked CCOEFF (lines 837-866). The two
   versions differ only in `multiply()` versus `Mat::mul()` spelling for the
   correction product; the arithmetic is identical.
3. Native algorithm: `n = sum(M)`; `T' = M*(T - sum(M*T)/n)` (mask applied
   twice, `M^2 = M` for canonical binary masks); `result = CCorr(I, T')`;
   `result -= CCorr(I, M) * (sum(T')/n)`. The last term is the **residual
   correction**: `sum(T')` is mathematically zero but not in Float32.
4. Both `crossCorr` calls use native DFT/block correlation. The newer masked
   path never enters unmasked `ipp_matchTemplate`.
5. Unmasked `matchTemplate(CCORR)` on 4.1.0 reaches `ipp_matchTemplate`, which
   forms `template.area()*4` in signed int, so the existing `unmasked_fits()`
   guard is required for the 4.1 composition only.

## Dispatch

| Version | Path |
|---|---|
| >= 4.10 | `cv::matchTemplate(image, patch, result, TM_CCOEFF, binary_mask)`, scores unmodified |
| 4.1.0 | `CCORR(I, Centered) - (sum(Centered)/n) * CCORR(I, M)` using unmasked `TM_CCORR` only |

Gate: `CV_VERSION_MAJOR > 4 || (== 4 && CV_VERSION_MINOR >= 10)`. The Ada API
does no version detection. Selector: `OPENCV_IMGPROC_TEMPLATE_CCOEFF`.

The 4.1 template sum and count are exact checked integer accumulations over
canonical 0..255 snapshots (no overflow: area <= INT_MAX/4 after the IPP
guard, 255 * area fits UInt64). The mean is one double division; the centered
Template and the residual are formed by native OpenCV arithmetic. The probe
showed the residual-corrected composition is closer to the oracle than the
uncorrected one (for the "full" fixture 0.0253 vs 0.0565 absolute error), so
the correction is retained.

## Degenerate masks (probe, all three versions)

* All-zero mask: native 4.10/5.0 return NaN (`-nan`), the 4.1 composition
  returns NaN, native 4.1.0 throws. Rejected before native execution for
  CCOEFF only (`invalid_argument`, destination untouched).
* One included pixel: ideal score 0; accepted. Observed scores are 0.
* Constant included Template and constant Scene windows: ideal 0; accepted;
  no forcing to zero. In the corpus these windows scored exactly 0.
* NCC `+0.0` and normalized SQDIFF `Float32'Last` rules are unchanged.

## Safety preflight

Shared `span_fits()` and `fits()` run on every branch. `unmasked_fits()` is
added only under the `#if` for the 4.1 composition (two unmasked CCORR
calls). The 30000 x 20000 geometry passes `fits()` and fails
`unmasked_fits()`; the harness asserts both, and on the legacy branch asserts
the IPP-area rejection of a forged header with an unchanged Destination. On
the native branch the same forged object used as Source and Destination is
rejected by object identity, before any forged pointer is read. No huge
image is allocated.

## Numerical policy (declared before measurement)

* Gate A: `|score - oracle| <= 1e-4 + 2^-20 * |Sum(M*T*I)|`. The floor is the
  proposed `1e-4`. The slope (about 8 Float32 ULPs of the dominant term) is
  scale dependent because the coefficient cancels two large correlations.
  A near-zero result is judged by this absolute bound, not by ULP distance
  from zero.
* Gate B: same bound between versions. ULP, relative error, nonfinite scores,
  sign disagreements and maximum-location differences are reported.
* Gate C: raw score bits equal the selected native control (>= 4.10) or the
  composition rebuilt in the harness (4.1).
* Gate D: designated robust landmarks must have a unique oracle maximum whose
  margin exceeds twice the uncertainty budget and agrees with the native
  maximum.

## Results

Corpus: 24 cases, 49,238 scores per version. Every version reports
`FAILURES 0`. Cross-version comparison for all three pairs:
max absolute difference 0, max relative difference 0, max ULP 0, 0 nonfinite
scores, 0 sign disagreements, 0 location differences.

Observed bitwise equality across all three versions was not required by the
gates; it was measured. It is plausible because the same canonical Float32
snapshots feed the same `crossCorr` code, and the 4.1 composition applies the
same arithmetic as the newer native code. This is evidence for this corpus
and for builds without IPP, not a universal guarantee.

Measured maximum absolute oracle error per case (4.10.0; identical on the
others): 0.0169 `landmark-full`, 0.0066 `landmark-sparse`, 0.0144 `inverted`,
0.0927 `dft-large` (scores up to 2.8e6). The first `landmark-full` window
(`STI = 974933`) differs from the exact coefficient by 0.00068, against a
bound of about 1.03 at that scale. Textured cases hold roughly 800 negative
and 800 positive scores each, so both covariance domains are exercised.
Black, constant, one-pixel and 1x1 cases score exactly 0 on every window.

## Limits of this evidence

* The local OpenCV builds use `WITH_IPP=OFF` and `WITH_TBB=OFF`; an IPP- or
  TBB-enabled build was not tested.
* The 5.0.0 libraries come from the existing prefix
  `/var/tmp/geometry-026/install-5.0.0` (the `/tmp/ocv/inst-5.0.0` prefix
  contains only core/flann/geometry).
* On 4.1.0 the harness control reimplements the same composition, so Gate C
  there confirms the shim matches its documented formula; it is not an
  independent native reference. Independent confirmation on 4.1.0 comes from
  Gate A (the integer oracle) and from equality with the newer native results.
* Many designated corpus cases (black, constant, one-pixel) have all-zero
  ideal scores by design; the positive and negative covariance domains are
  covered by the textured, offset, scaled and inverted cases.
* Windows hosted CI is not evidence for this feature.
