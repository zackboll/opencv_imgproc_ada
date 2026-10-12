# Portable masked cross-correlation: source review and qualification

## Starting gate

Fetched `origin/main`: `5633ad076602421ef945e3b7bc36891e7ea09346`.
Fresh Linux Alire build and AUnit baseline: **1110/1110 PASS**.
No open repository PRs were found. Existing worktrees were preserved.
Feature worktree: `/tmp/imgproc051-masked-ccorr`, branch
`feature/051-masked-cross-correlation`.

The post-merge workflow at
https://github.com/zackboll/opencv_imgproc_ada/actions/runs/38194933985
completed with Linux and macOS success, but Windows failed in MSYS2 package
installation before build/tests. Installing libgcc/libstdc++ 16.2.0-5
conflicted with dependencies requiring 16.2.0-4. Windows is **not validated**.

## Exact source findings

Reviewed both `matchTemplateMask` and ordinary `matchTemplate`, plus their
correlation and IPP helpers, at these exact upstream sources:

- https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/templmatch.cpp
- https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/templmatch.cpp
- https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/templmatch.cpp

4.1.0's masked implementation has only SQDIFF and CCORR_NORMED branches;
other selectors throw StsNotImplemented. All three ordinary unmasked
implementations support CCORR, with `common_matchTemplate` immediately
returning for that selector after native correlation. The newer masked
CCORR branches form `templ.mul(mask.mul(mask))` and call `crossCorr`.

For canonical 0/1 masks, M squared equals M, so correlating Image with
Template whose excluded samples are zero is mathematically equivalent.
This does not establish bit-identical floating-point results. Ordinary
unmasked dispatch can use IPP, whereas the masked implementation directly
uses crossCorr; native optimized/backend paths can round differently.

## Production construction

The shim snapshots logical UInt8 C1 rows into local owning Float32 C1 Mats.
Image and Template keep original intensity units, 0..255. Every nonzero
mask byte becomes exactly 1. The new branch constructs an owning
`masked_patch = patch.mul(binary_mask)`, then calls
`cv::matchTemplate(image, masked_patch, result, cv::TM_CCORR)` with **no mask
argument**, identically on every version. No custom correlation kernel is used.
SQDIFF and NCC retain their native masked calls; NCC's positive template
energy check and exact zero-Scene compatibility rule are unchanged.

CCORR scores are unnormalized included intensity-product sums; maximum is
best. Black templates and all-zero masks are allowed. Native signed zero is
preserved. No general score clamp or exact-zero correction has been added.

## Safety review

The existing shared planner bounds signed input/template/output areas,
Float32 snapshot allocation extents, logical byte strides and Region spans,
4.5-scaled native blocks, optimal DFT sizing, Float64 DFT row-step narrowing,
tile counts and pointer extents. Owning snapshots isolate parent pixels and
overlapping inputs. The zeroed-template multiplication uses those same
bounded extents. Results remain local until move publication; identical
input/output native objects reject, while distinct shared-storage headers
are snapshotted before publication. Exceptions are caught and translated.

Ordinary CCORR additionally reaches `ipp_matchTemplate`, which evaluates
`templ.size().area()*4` in signed int before deciding to use IPP. A
CCORR-only `unmasked_fits` check rejects template area above INT_MAX/4.
This is an arithmetic safety bound, not an arbitrary size cap. The IPP
source/template/output row steps are narrowed to int; their Float32 widths
are bounded by Source width, already protected by the shared planner.
OpenCL is not selected because the destination is Mat, not UMat. IPP's
internal implementation and buffer-size query remain trusted native code.

Retained semantic-looking checks and concrete safety reasons:

- UInt8 C1/nonempty 2-D and spans: row snapshots perform typed pointer reads.
- Matching template/mask dimensions: elementwise template masking requires
  compatible extents before processing/publishing native storage.
- Template fit/planner geometry: native signed arithmetic and allocation.
- Selected methods: other branches use unqualified centering arithmetic.
- Positive NCC template energy: existing compatibility check avoids native
  version-dependent ones versus NaN. It does not apply to CCORR.

No additional public semantic validation was added in the C++ shim except
conditions documented above with ABI-safety reasons.

## Original numerical experiment and failed gate

The corpus calls the actual production shim and Core module bridge. It
records geometry, active pixels, every raw Float32 score bit, independent
integer sum, maximum location/score, and best/second-best margin. UInt64
accumulation checks every addition against overflow; each product is at most
65025. The bounded corpus sum is also checked against 2^53 before floating
conversion, keeping the integer-to-double reference exact.

The DFT ceiling was fixed before measurements at
`2^-19 * active pixels * 65025`. Small designated exact fixtures were assigned
zero tolerance. That exact criterion **failed** for sparse landmark maps:

`landmark`, output (0,0): oracle 0, native
`-7.5791227406498546e-14` on 4.1.0.

Other mathematically zero windows in landmark/brightness/excluded-corruption
fixtures also show tiny native DFT residuals. The original gate did not pass.
Measurements are preserved in
[original failure evidence](masked-ccorr-original-measurements.md) and in local
archived maps/logs. FFT computation uses rounded forward/inverse transforms
and spectral multiplication; integer input and exactly representable sums do
not imply an integer-exact Float32 result. This is expected DFT rounding, not
evidence of an intensity scaling or mask-weight mismatch. The continuation
explicitly authorized a revised oracle policy; no fixture was removed and
the native algorithm was not changed to force exact scores.

An initial all-zero-mask check incorrectly required positive-zero bits.
Investigation identified `0x80000000` (-0.0), not a nonzero residual, for
3x1-mask2. The requirement is mathematical zero, and either signed zero
meets it. All all-zero-mask scores observed were numerically zero.

GCC measurements: 34 fixtures, 882 output samples per exact version.
Pairwise 4.1.0/4.10.0, 4.1.0/5.0.0 and 4.10.0/5.0.0 comparisons each had
maximum absolute difference 0, relative difference 0, ULP difference 0,
no nonfinite scores and no maximum-location differences. Native masked
controls on 4.10.0 and 5.0.0 had max absolute/relative difference 0.
4.1.0 has no masked control; its printed zero control statistic is not a
measurement of an unavailable implementation. These are corpus-specific
measurements, not a general bitwise-equivalence guarantee.

Near-tie maximum was index 0, score 26010000, native margin 254, on all
versions. The exact integer margin is 255; the two-unit spacing of Float32
at that magnitude explains the rounded score margin. The generic DFT
ceiling does not by itself guarantee ranking at arbitrary smaller margins.

## Revised acceptance policy (explicit continuation review)

Gate A independently computes checked UInt64 sums, rounds them to Float32,
and requires absolute error at most `max(1e-4, 4 * ULP(rounded oracle))`.
ULP is computed using adjacent Float32 values (`nextafter`), not a Float64
spacing approximation. Every sample records reference bits, exact integer
representability, error, error in reference ULPs, fixed ceiling and native
finite classification. This ceiling was selected by review before expanded
measurements, not fitted to their errors. Negative residuals are not clamped.

Gate B independently requires **exact Float32 bits across all three versions**,
including the original 34 cases. Any bit disagreement fails regardless of
Gate A tolerance. Nonfinite scores fail and are reported. Native masked
controls on newer versions record raw score bits and absolute/relative
differences; 4.1.0 controls are explicitly unavailable.

Gate C independently requires oracle/native maximum-location agreement for
claimed unambiguous landmarks. Exact integer best/second scores, native
best/second scores, both margins and a conservative combined uncertainty
budget are recorded. The budget is twice the maximum per-score oracle ceiling
plus integer-to-Float32 rounding error in that map. Robust oracle margins must
exceed this budget. Mathematically tied multiple-perfect candidates are
retained but are not claimed unique.

## Expanded qualification results

Both strict GCC and Clang 19 runs passed all three gates on exact 4.1.0,
4.10.0 and 5.0.0: **44 fixtures, 1035 samples per version**. All original
34 fixtures remain. Added cases cover surrounded-zero windows, full/sparse/
single-pixel/nonbinary/all-zero masks, multiple perfect candidates, a margin
of one, odd integer scores above 2^24, and simultaneous overlapping Regions.
Generation is deterministic arithmetic without random seeds.
One-row and one-column maps are included. A sub-ULP near-tie is deliberately
not claimed robust: integer scores 25945230 and 25945229 both become native
25945230, yielding a tie. This loss of a one-unit distinction is recorded on
every version rather than hidden by a unique-landmark claim.

Maximum absolute rounded-oracle error: **2** score units. Maximum positive
oracle error: **1 Float32 ULP**. Including exact-zero references, maximum
error divided by reference ULP is `1.1076900542579651e34`; zero has spacing
2^-149, so this large ratio describes tiny residuals, not large score error.
Maximum ordered-bit ULP distance from the reference is **763922569**.
The fixed absolute floor is therefore important near zero. These diagnostic
definitions are distinct and are not substituted for the acceptance ceiling.

Every pairwise version comparison: absolute difference **0**, relative
difference **0**, ULP difference **0**, no nonfinite scores, no maximum-location
changes. On 4.10.0/5.0.0 the native masked controls have maximum absolute and
relative difference **0**. This is measured corpus agreement, not a universal
backend bitwise promise. All-zero masks give numeric zero, either sign.

| Fixture | Oracle best / second | Native best / second | Oracle / native margin | Combined budget |
|---|---|---|---|---|
| landmark | 4059 / 1643 | 4059 / 1643 | 2416 / 2416 | 0.001953125 |
| brightness | 8118 / 3286 | 8118 / 3286 | 4832 / 4832 | 0.00390625 |
| excluded-corruption | 13515 / 7905 | 13515 / 7905 | 5610 / 5610 | 0.0078125 |
| near-tie | 26010000 / 26009745 | 26010000 / 26009746 | 255 / 254 | 18 |
| integer-margin-one | 255 / 254 | 255 / 254 | 1 / 1 | 0.0002 |
| above-2pow24-odd | 26010000 / 26009745 | 26010000 / 26009746 | 255 / 254 | 18 |
| multiple-perfect | 65025 / 65025 | 65025 / 65025 | 0 / 0 | 0.03125 (not unique) |
| near-tie-sub-ulp | 25945230 / 25945229 | 25945230 / 25945230 | 1 / 0 | 18 (not robust) |

## Reproduction and validation

From the feature worktree root:

```sh
sh tests/qualify_masked_ccorr_versions.sh \
  "$HOME/.cache/video-task004/install-4.1.0" /usr \
  "$HOME/.cache/video-task004/install-5.0.0"
```

The qualification script now passes the explicitly revised Gate A and the
independent exact-bit Gate B and ranking Gate C. Header/runtime equality is
checked inside each harness; each successful runner checks actual loader paths
and records `.build` and `.loader` evidence. Set `CXX=clang++-19` to repeat
with Clang. Set `SANITIZE=1` for project shim/harness instrumentation.

Separate `ldd` inspection verified the actual Core and Imgproc loader paths:
4.1.0 and 5.0.0 resolved inside the corresponding
`$HOME/.cache/video-task004/install-VERSION/lib` prefixes; 4.10.0 resolved
inside `/usr/lib/x86_64-linux-gnu`. Header/runtime equality passed in all
three harness runs.

Strict GCC and Clang 19 C++17 builds passed with
`-Wall -Wextra -Wpedantic -Werror`. Both ASan/UBSan expanded harness runs
passed against installed 4.10.0 without sanitizer diagnostics. Instrumentation
covers project Imgproc/Core shims and harness, not prebuilt OpenCV libraries.
Forced scoped strict Ada compilation passed for the changed library body,
three changed test bodies and runner with
`-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror`.
GNATformat was applied to changed Ada. No SPARK-designated unit changed;
no proof campaign was run.
Changed-Ada 79-column checks, both shell syntax checks and `git diff --check`
passed. Arithmetic-boundary rejection is exercised through forged borrowed
native headers in the production corpus before any large allocation; the
focused AUnit tests exercise public invalid representations, oracle scores,
locations, failure atomicity, recovery, Region isolation and ownership.

Post-change normal build/full AUnit: **1116/1116 PASS**, including focused
CCORR **6/6**. Focused existing
masked SQDIFF: **6/6**, NCC: **9/9**, unmasked matching: **10/10**.

The public API admits the three requested methods, preserving
the default and unmasked overload. Existing SQDIFF/NCC rejection loops were
updated accordingly. The original 1110 tests still pass after this change.
README documents the three methods and an Ada example. Linux hosted CI adds
a bounded sanitized production regression; macOS and Windows policies are
unchanged. Single-version hosted CI is not three-version consistency proof.
Independent diff review and exact-head hosted CI review remain required;
this document is not a merge-readiness claim.