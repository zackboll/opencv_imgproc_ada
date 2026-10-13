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
* Corrected Gate D: retain each exact oracle coefficient and integer `STI`.
  With `E[i] = 1e-4 + 2^-20 * abs(STI[i])`, require a unique oracle winner
  and `O[best] - E[best] > max(O[j] + E[j], j != best)`. All candidates
  participate, not only the runner-up by score. Designated landmarks also
  require a unique native maximum at the same coordinates. Mathematical ties
  and overlapping uncertainty intervals are never robust.

The original feature commit incorrectly scaled Gate D with the centered
coefficient and checked only its score margin. That coefficient can be tiny
while the two uncentered correlations being subtracted are large; it is not
an appropriate rounding-error scale. Previously reported robustness is not
proof under the corrected budget. Gates A/B and cross-version score
consistency were unaffected. The original ranking claim is superseded by
this corrective evaluation.

## Original 24-case qualification history

The following results describe the original feature commit, including its
unmodified `corrupt-scene` clone and defective Gate D. They establish score
consistency for that original corpus, not corrected ranking robustness.

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

## Corrective qualification of PR #51

Starting feature HEAD: `2790aa4aad7ba7fe8523d66c97d178c3dd400fca`.
Production C++/Ada and workflows are unchanged. The original 24 fixture names
and 49,238 output windows remain; one two-window qualification fixture was
added (25 fixtures / 49,240 scores total).

### Ranking results (identical across versions and compilers)

| Designated landmark | Oracle/native maximum | Score margin | Winner E | Alternative E | Worst separation |
|---|---|---:|---:|---:|---:|
| landmark-full | (21,13) | 110717.190476 | 1.409287317 | 1.214355333 | 110714.566834 |
| landmark-sparse | (21,13) | 55048.191489 | 0.963464601 | 0.952700479 | 55046.275324 |
| dft-large | (60,40) | 1304627.621723 | 10.940733774 | 9.635524614 | 1304607.045464 |

Each has exactly one oracle and native maximum, and passes corrected Gate D.
The old gate required a margin above `4e-4 + 2^-18 * abs(best)`:
approximately 1.28293, 0.95238 and 10.67177 respectively. The corrected
winner-plus-most-competitive-alternative allowances are 2.62364, 1.91617
and 20.57626. These landmarks remain robust, but only the new all-candidate
calculation supplies that evidence.

`exact-ties` has two oracle/native maxima and zero margin. The original
`near-tie` is actually an exact tie with five oracle/native maxima; its
uncertainty-adjusted separation is -0.0689599182. Both remain explicitly tied.
The new `ambiguous-near-tie` uses 100 Template pixels: 99 values of 254 and
one of 255, against two windows with one and two 255 values. Its unique
oracle winner has margin 0.01, winner E 6.153310640 and worst separation
-12.296863513. It is ambiguous even though every version selects the same
native maximum. Synthetic ranking regressions additionally cover exact ties,
overlapping near-ties, and a competitive alternative other than the score
runner-up. Scores 10 and 9 with STI 100,000,000 would pass the old threshold
0.000438147, but their corrected combined budget is 190.735063281 and they
are rejected. These tests do not involve OpenCV or DFT rounding.

Every RANK record includes oracle/native coordinates and tie counts, best
and second score, margin, winner bound, most competitive alternative index,
score and bound, worst separation, classification and required-landmark flag.
The comparator independently reconstructs these facts, checks all samples
and bounds, rejects missing/duplicate ranking records and truncated maps,
and requires successful final termination. One binary64 ULP is allowed only
when reconstructing serialized long-double bounds; score gates are unchanged.

### Genuine excluded Scene corruption

Only excluded mask positions within the landmark at Scene (21,13), size
9 x 7, are inverted with `255 - pixel`. The 16 local (u,v) positions are:
(0,0), (4,0), (8,0), (1,1), (5,1), (2,2), (6,2), (3,3), (7,3),
(0,4), (4,4), (8,4), (1,5), (5,5), (2,6), (6,6).
Absolute Scene coordinates are (21+u,13+v):
(21,13), (25,13), (29,13), (22,14), (26,14), (23,15), (27,15),
(24,16), (28,16), (21,17), (25,17), (29,17), (22,18), (26,18),
(23,19), (27,19).

All 16 change; included pixels and every other Scene pixel remain unchanged.
The original Scene is checked unchanged. All four exact sums at (21,13)
remain identical, including STI 1,010,161; hence coefficient and Gate A bound
are unchanged. Both production scores pass Gate A and differ by 0 in all
runs, against the justified sum-of-two-error-bounds allowance 1.9269292023.
Other sliding windows are independently qualified against their own integer
oracles; whole-map equality is neither asserted nor expected. The existing
Template-corruption and Region/source-immutability tests remain.

### Requalification

Header/runtime equality (`CV_VERSION == cv::getVersionString()`) is asserted
before the corpus. Exact version/branch records are 4.1.0 compatibility,
4.10.0 native and 5.0.0 native. Existing Linux loader checks verify both
core and imgproc resolve within `/tmp/ocv/inst-4.1.0/lib`,
`/tmp/ocv/inst-4.10.0/lib`, and
`/var/tmp/geometry-026/install-5.0.0/lib`, respectively, not just header
or pkg-config identity.

Strict C++17 GCC and Clang 19 runs pass Gates A/C/D on all 49,240 scores.
Gate B across all three version pairs reports maximum absolute/relative/ULP
difference 0, no nonfinite values, sign disagreements or maximum-location
differences. Native-control bit mismatches are 0. GCC and Clang 19 ASan/UBSan
runs also pass on all three versions; only project shim/harness sources,
not prebuilt OpenCV libraries, are sanitizer-instrumented.

Focused AUnit results: CCOEFF 6/6, masked SQDIFF 6/6, normalized SQDIFF 7/7,
CCORR 6/6, NCC 9/9, unmasked template matching 10/10. Full suite: 1129/1129.
No Ada source changed, so strict changed-Ada compilation is not applicable.
Shell syntax and `git diff --check` pass. Local logs are preserved under
`/tmp/ccoeff-correct-*.log`; exact-version output/build/loader records are
under `tests/bin/masked-ccoeff-qualification` (ignored build artifacts).

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
