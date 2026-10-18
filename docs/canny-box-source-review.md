# IMGPROC-API-001: gradient Canny and generalized box filtering

## Provenance and reviewed sources

Starting fetched origin/main: `6715ed13ee8d2ea0f4ac089722ed926cfef77eb6`.
The working tree was clean; no open PR or matching feature branch existed.
Work is on `feature/imgproc-api-001-canny-box-filter`, not main.

Reviewed existing `Canny_Edges`, `Box_Blur`, `Squared_Box_Filter`, `Filter_2D`,
`Sep_Filter_2D`, their thin imports, C exports, depth/border/alias validators,
`squared_box_layout_fits.hpp`, AUnit suites and native harnesses. Reviewed Core
`Module_Interop`, `opencv_core_module_bridge.hpp`, row access, Regions and
storage overlap. Core owns every Mat header/allocation; handles are borrowed
only during callbacks. A Region is a reference-counted header, not an external
buffer view; output resolution rejects non-rebindable temporary views.

Exact upstream tags inspected (installed source trees and authoritative
GitHub Canny source): **4.1.0, 4.6.0, 4.10.0, 5.0.0**. For each tag, inspect:

* `modules/imgproc/include/opencv2/imgproc.hpp`: both Canny declarations,
  boxFilter declaration and defaults.
* `modules/imgproc/src/canny.cpp`: derivative overload, parallelCanny,
  magnitude, direction, map allocation, hysteresis, IPP/OpenCL dispatch.
* `modules/imgproc/src/box_filter.dispatch.cpp`: Mat path, singleton
  reduction, HAL/OpenVX/IPP selection and FilterEngine (5.0 also BlockSum).
* `modules/imgproc/src/box_filter.simd.hpp`: RowSum/ColumnSum, supported
  source/sum/output depth combinations, accumulator selection; 5.0 BlockSum.
* `modules/imgproc/src/filter.dispatch.cpp` and `filter.simd.hpp`: anchors,
  scratch/border tables, ring-buffer arithmetic and row-pointer formation.

Permanent source roots:
[4.1.0](https://github.com/opencv/opencv/tree/4.1.0/modules/imgproc),
[4.6.0](https://github.com/opencv/opencv/tree/4.6.0/modules/imgproc),
[4.10.0](https://github.com/opencv/opencv/tree/4.10.0/modules/imgproc),
[5.0.0](https://github.com/opencv/opencv/tree/5.0.0/modules/imgproc).

## Canny: types, backends and actual arithmetic limits

Every reviewed derivative overload asserts 2-D CV_16SC1/CV_16SC3, equal type
and size, and creates CV_8UC1. C3 chooses the strongest magnitude channel.
No Sobel is called (`needGradient=false`). Row strides are honored. Output
creation precedes acquiring derivative Mat copies, so passing the same
native Mat as a derivative/output is not a safe general in-place contract.
The binding rejects object identity and actual byte overlap with either
derivative. Derivatives may overlap each other. Both inputs remain unchanged.

Mat outputs do not enter the UMat-only OpenCL path. Optional IPP derivative
Canny can run before the portable CPU implementation; otherwise parallel
SIMD/scalar Canny runs. No global backend/thread setting is changed. Backend
rounding/channel tie behavior is native, not normalized by the binding.
In particular the reviewed L1 SIMD code reinterprets abs(-32768) as signed
short before expansion; scalar and SIMD extreme-value results need not agree.

Native hazards are source-level, not inferred from successful sanitizers:

* Scalar L2 uses `int(dx)*dx + int(dy)*dy`; (-32768,-32768) sums to 2^31.
* Direction uses `x=abs(dx)`, `y=abs(dy)<<15`, `tg22x=x*13573`, and on the
  `y>=tg22x` branch `tg67x=tg22x+(x<<16)`. Reject a pair when that branch is
  reachable and `x*79109>INT_MAX`, independently of magnitude/threshold.
  (32767,32767) is an explicit counterexample. No rescaling or clipping.
* L1 thresholds reach `cvFloor` without native upper saturation; reject above
  INT_MAX. L2's native algorithm limits thresholds to 32767 before squaring;
  preserve that documented native behavior, but first require finite Float32
  representability because IPP dispatch narrows to float. NaN, infinities,
  negatives and reversed thresholds are public Ada errors.
* Maps allocate rows+2 and SIMD-aligned cols+padding; magnitude storage uses
  `3*(mapstep*channels+SIMD_width)` in signed arithmetic; C3 allocates 2*cols;
  parallel row offsets include signed row*mapstep. `canny_layout` conservatively
  bounds all with widened arithmetic, a 64-byte fixed-SIMD maximum, INT_MAX
  map span and PTRDIFF_MAX allocation span. Builds with a wider/scalable SIMD
  implementation beyond this qualification are not claimed supported.
* Input row widths, strides and complete final-row extents are bounded before
  the shim scans paired short rows. Layout validation precedes native calls.

Public Ada validates semantics, thresholds, aliases and sample arithmetic
(through Core row access). The shim independently repeats sample/layout
checks because raw C callers must not reach native undefined signed behavior.
Failures leave the existing destination untouched. Success moves a local
owning result into Core's borrowed destination header; no handle ownership is
transferred, destroyed or retained.

## Box_Filter: portable depth matrix and numerics

All four source families support UInt8, UInt16, Int16, Float32 and Float64
row sums and same-depth output. Via existing Filter_Depth the public matrix is:

| Source | Same | Int16 | Float32 | Float64 |
|---|---|---|---|---|
| UInt8 | yes | yes | yes | yes |
| UInt16 | yes | no | yes | yes |
| Int16 | yes | yes | yes | yes |
| Float32 | yes | no | yes | yes |
| Float64 | yes | no | yes | yes |

This matrix differs from Filter_2D: box sums permit both floating conversions.
Int8, Int32 and Float16 sources and an Int32 output selector are excluded.
Channel counts are preserved and processed independently, subject to native
layout bounds. Tests exercise C1/C3/C4 and every exposed depth combination.

UInt8 -> UInt8 with area<=256 uses UInt16 sums. Other integer sources use
signed int for all unnormalized requests, even with floating output, and for
normalized area <=2^23 (UInt8), <=2^15 (UInt16), <=2^16 (Int16). Larger
normalized kernels use double sums. Float sources use double accumulators.
Thus unnormalized safe area limits are 8,388,608 / 32,768 / 65,536 respectively.
Int16's minimum at area 65,536 is exactly INT_MIN, not an overflow. Signed
kernel-area multiplication itself must fit INT_MAX in every mode; native
row/column/ring/block arithmetic imposes additional, often tighter bounds.

Integer outputs use native rounding and saturation, not modular wrap.
Floating outputs preserve native loss of significance, NaN/Inf propagation
and overflow; rolling sums can retain nonfinite/high-dynamic-range history
beyond the ideal local window. OpenCV 5.0 adds small-kernel same-depth floating
BlockSum, so bitwise cross-version floating equality is not promised. The
native corpus allows 1e-4 Float32, 1e-10 other floating and one integer unit
for normalized UInt8 backend rounding; exact small AUnit oracles remain exact.

## Box safety adapter and Region semantics

The existing squared-box shifted-layout strategy is reused, not its numeric
algorithm. The shim calls **cv::boxFilter exactly once** with the requested
output depth and normalization. It does not sum/filter pixels itself.

Effective kernel dimensions reduce normalized nonconstant singleton axes to
one; explicit anchors on those axes reduce to zero. Constant and sum modes
retain the full kernel. This is native isolated-image semantics, not silent
kernel-size clamping. Native unisolated Box_Blur remains unchanged.

For effective kw,kh and original cols,rows, native width/height are expanded
to at least two on normalized axes with kernel extent >1 (avoiding unwanted
native singleton behavior). Private owning parent dimensions are
`(native_width+kw-1) x (native_height+kh)`. Each pixel is copied bytewise from
the logical input at `(x-anchor_x,y-anchor_y)`, mapped using the requested
border, or zero for Constant. Reflection uses widened periodic arithmetic.
Native input ROI begins at parent (0,0), has anchor (0,0), Replicate native
border and trailing halo; no typed horizontal border-table or synthetic
constant-row copies are needed. The extra bottom row contains FilterEngine's
unconditional final pointer increment. Crop and clone publish only original
geometry. Distinct overlapping destination headers safely detach; identical
objects are rejected. Previous destination aliases/Region parents stay intact.

The allocation-free planner bounds positive dimensions, kw*kh, padded
dimensions, channel-expanded widths, worst-case eight-byte element widths,
64-aligned ring steps, max(kh+3,2*(kh-1)+1) rows, signed row-offset products,
native batch products and PTRDIFF_MAX extents. OpenCV 5 BlockSum's signed
`(width+kw-1+VEC_ALIGN)*(kh+1)*element_size` allocation is additionally bounded.
Every factor is bounded before subsequent multiplication. Strided donor
extents are checked before pointers are formed. No raw Mat layout can be
fabricated through the public Ada API; malformed valid-handle C arguments are
still independently guarded.

OpenCV's internal FilterEngine numeric scratch-storage object lifetimes are
trusted third-party implementation details, consistent with the repository's
accepted squared-box dependency assumption. Known signed overflow and OOB
paths are not accepted. Arbitrary custom HAL/IPP/OpenCL builds are not proved
safe by this campaign; the listed exact-version Linux installations are the
executed evidence. Production platform-specific runtime/link isolation is
unchanged; the native reference retains the existing separate DLL/dylib scheme.

## Validation-boundary review

Retained duplicated conditions and concrete ABI reasons:

* Canny paired 2-D Int16 C1/C3 equal geometry/type and nonempty layout: required
  by the shim's paired short-row reads and native padded indexing.
* Canny finite/ranged thresholds: native float/int conversions must be defined.
* Canny aliases: preserve borrowed input objects/storage at output publication.
* Canny sample limits: native signed L2/direction arithmetic must not overflow.
* Box positive kernel, 2-D geometry, legal anchor, nonidentical objects: adapter
  halo construction and source-preserving publication must remain valid.
* Box supported border representation: adapter donor mapping cannot interpret
  Wrap/unknown selector as reflection.
* Box kernel/accumulator limits: native signed products/sums must not overflow.
* Layout/stride bounds in both operations protect pointer formation, buffer
  allocation and native signed indexing. ABI selector validation is mechanical.

Every semantic-looking retained shim guard has an `ABI safety:` justification.
Pure public depth-combination restrictions are Ada-only; safe raw mismatches
may fail through native exception translation. All potentially throwing work
is inside catch-all exception translation, with local results published last.

## Executed qualification and exclusions

Baseline: **1140/1140** registered AUnit tests. Current: **1147/1147**.
Seven added registered routines cover multiple independent data cases.

| Version | Linux full release AUnit | Native-reference / malformed ABI | ASan/UBSan including native OpenCV |
|---|---|---|---|
| 4.1.0 | 1147/1147 | 48 Canny + 24480 box PASS | PASS |
| 4.6.0 | 1147/1147 | 48 Canny + 24480 box PASS | PASS |
| 4.10.0 | 1147/1147 normal development/test invocation | 48 Canny + 24480 box PASS | PASS |
| 5.0.0 | 1147/1147 | 48 Canny + 24480 box PASS | PASS |

Commands (repository root): `alr -n build`, `alr -n -C tests run`,
`sh tests/run_canny_box_native.sh`, `git diff --check`. Native-version runs
set PKG_CONFIG_PATH to exact installed prefixes and set OPENCV_TEST_PACKAGE
to opencv5 for 5.0; sanitizer runs use instrumented prefixes, SANITIZE=1 and
UBSAN_OPTIONS=halt_on_error=1. Tests compile both production shims. Full
multi-version AUnit uses `alr -n -C tests build --profiles='*=release'`, then
`alr -n -C tests run --skip-build`, with matching LD_LIBRARY_PATH.

One earlier cross-version attempt ran concurrently with a documentation build
in the same tree and failed 40 validity checks; it is not qualification.
Sequential release builds above passed. No unrelated validators were changed.
GNATdoc 26: zero warnings; generated-site checks and 1534/1534 documentation
coverage passed. GNATformat applied only changed Ada sources/regions.

GNAT 12 source-policy checks could not run locally: gcc-12 is present but its
`gnat1` frontend is missing. Existing hosted GNAT12 source-unit workflow must
qualify the new units. No new Ada-2022-only construct was introduced.
No GNATprove claim: changed entry points cross controlled Mat/foreign callback
boundaries and are not SPARK proof units. Runtime checks/tests are evidence,
not proofs. macOS ARM64, macOS x86_64 IPP and Windows hosted status, final
tested commit/PR HEAD and independent review disposition belong in the PR's
exact-head report; local Linux success does not establish those gates.