# Portable native linear image blending: exact-source review

## Pinned evidence

| Exact tag | Commit |
| --- | --- |
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Reviewed each exact tag's `modules/imgproc/include/opencv2/imgproc.hpp`,
complete `modules/imgproc/src/blend.cpp` (both SIMD overloads, `blend`,
`saturate_f32_u32`, packing and `BlendLinearInvoker`), and
`modules/imgproc/src/opencl/blend_linear.cl`. Also reviewed Core headers
`modules/core/include/opencv2/core/saturate.hpp`, `fast_math.hpp`, and relevant
division/rounding helpers in `hal/intrin_sse.hpp` and `hal/intrin_neon.hpp`.
Also inspected `mat.inl.hpp`/`matrix_wrap.cpp` for size/row-pointer behavior
and `hal/interface.h` for native channel representation.
Append these paths to the exact-tag links for reproducible evidence. Tagged
Git objects and native retrieval were used, not rolling main.

## Public contract and header-versus-source discrepancy

All three headers accept `CV_8UC(n)` or `CV_32FC(n)`, positive n, a second
source of identical type/size, and two matching-size `CV_32FC1` weight maps.
The signature has four InputArrays and one OutputArray, no defaults. 4.1
uses `CV_EXPORTS`, later versions `CV_EXPORTS_W`, with no signature change.
No Geometry or general Core arithmetic dependency is needed.

The header's displayed weighted-sum formula **omits normalization**. Actual
CPU scalar code in all three tags evaluates binary32:

```text
den = w1 + w2 + 1e-5f
num = src1[channel] * w1 + src2[channel] * w2
dst[channel] = saturate_cast<T>(num / den)
```

One scalar weight pair per logical pixel applies to every channel. `(1,1)`
approximates the average, not the sum; `(1,0)` is not exact identity. Both zero
weights produce zero for finite sources. Float32 IEEE cases such as `Inf*0`
are not overwritten with zero. Weights need not sum to one. The binding calls
native `cv::blendLinear`; it adds no manual arithmetic or normalization pass.

Ada requires all four images nonempty and 2-D. Sources have matching geometry,
depth/channels, UInt8 or Float32 depth, and any channels represented by Core
subject to native width safety. Weights are matching Float32 C1; **every
logical sample is finite and in [0,1]**. Ada scans borrowed zero-copy Core
rows. Float32 source samples have no finiteness or range restriction.

## Scalar, SIMD, UInt8 conversion and Float32 IEEE behavior

Scalar `x/cn` selects the weight pixel. Float32 casts do not clamp arithmetic:
NaN, signed infinity and intermediate overflow retain native IEEE behavior.
NaN payloads and cross-platform Float32 bit identity are not promised.

SIMD specializes C1/C2/C3/C4; other channels return x=0 for full scalar
execution. SIMD uses the same numerator and sum-plus-epsilon denominator.
UInt8 expands to Float32, `v_round`s, clamps integer lanes to 0..255 and packs.
Scalar `saturate_cast<uchar>(float)` calls **cvRound before clamping**.
cvRound uses SSE, x87, lrintf/builtins or a 4.1 fallback cast after +/-0.5.
Usual SSE/many NEON paths round nearest/even, but legacy NEON/fallback tie
behavior is not a universal ties-to-even promise. UInt8 tests use exact
expectations away from ambiguous ties. Float32 tests use tolerances.
4.1 non-AArch64 NEON divides using reciprocal estimate and two refinements;
other platforms use hardware division. That alone refutes a universal last-bit
promise; compiler contraction and rounding can also affect Float32 results.

UInt8 sources with finite [0,1] weights yield positive denominator, finite
nonnegative numerator and a quotient near 0..255, far inside the signed-int
conversion envelope. Raw arbitrary weights can yield NaN/Inf/out-of-int
results. Since cvRound precedes saturation, portable fallback conversion can
be undefined. The shim conservatively repeats finite [0,1] scanning **only
for UInt8**, for that native-conversion safety reason. Raw Float32 weights
retain native arithmetic, including out-of-range and nonfinite values.

## Signed width, SIMD indexing, strides and parallel geometry

The invoker computes `int width = src1->cols * cn`. Before native entry the
allocation-free helper widens operands and requires **columns*channels <=
INT_MAX**. No total-pixel or arbitrary practical cap is added. Negative columns
and nonpositive channels are malformed. Zero columns is arithmetic-safe in
the helper; public empty-image policy belongs to Ada. Operand bounds prevent
even malformed int64 helper inputs from overflowing the widened product.

Let B be UInt8 vector lanes and F Float32 lanes (B=4F):

| SIMD path | Block / x increment | Weight increment |
| --- | --- | --- |
| UInt8 C1 | B | B |
| UInt8 C2 | 2B | B |
| UInt8 C3 | 3B | B |
| UInt8 C4 | B | F |
| Float32 C1..C4 | cn*F | F |

Every loop uses `x <= width - block`, not potentially overflowing x+block.
Entered iterations advance x to at most width. UInt8 weight-offset additions
0/F/2F/3F load groups inside the loop's B logical pixels. Float32 and UInt8
C4 offsets advance by exactly the processed pixel count. Deinterleave/store
accesses cover precisely the bounded block. Lane products are small native
vector constants (or supported scalable counts), not data-sized products.
width-block can be negative on short rows without signed underflow for
supported lanes. Scalar tails have x<width, x/cn<cols; final x++ may reach
INT_MAX but not INT_MAX+1. No additional data-dependent SIMD guard is needed.

Raw Source_1 must not be n-D: 4.x release MatSize::operator() only debug-asserts
2-D, so native size can allocate a 2-D result while Source_1.rows=-1 skips
the invoker, leaving allocated pixels uninitialized. 5.0 size() asserts 2-D.
UInt8 scans require 2-D Float32 C1 weights: a rows=-1 scan could otherwise
skip unsafe values in n-D weights whose first two dimensions pass 4.x size().
The float-row layout requirement prevents incompatible reinterpretation. Other
source/weight type/geometry matching is left to native assertions, before
the invoker. Ada owns the full public contract.

Rows use `ptr<T>(y)`, whose step multiplication is size_t, not a narrowed
signed stride. Core/OpenCV Region headers retain valid allocation bounds.
The shim constructs no external view or packed signed row arithmetic. Original
parent strides work without continuity checks, stride caps, or snapshots.
Only logical columns are scanned; parent pixels/padding never participate.

Parallel work is `Range(0, src1.rows)`, grain estimate
`dst.total() / (double)(1<<16)`. Mat total is size_t; estimate division is
double; row coordinates are int. There is no signed rows*cols/rows*width
product here. Tasks write disjoint local-result rows.

## OpenCL, allocation, aliasing and version differences

The OpenCL kernel also normalizes with 1e-5 and uses per-channel conversion
and int/mad24 byte offsets. It is **unreachable** here: dispatch requires
`_dst.isUMat()` but this shim supplies a local `cv::Mat` OutputArray. OpenCL
index restrictions must not be imposed on this CPU-only boundary. No IPP or
Geometry algorithm dispatch exists in the reviewed native function.

Native `_dst.create(size,type)` allocates the initially empty local result.
Four inputs are borrowed read-only; move-rebinding the Core destination happens
only after complete native success. Raw failure preserves prior destination
header/storage. The public result owns fresh storage through Core. Identical
or overlapping sources, identical weights, and compatible source/weight storage
sharing need no snapshots. Regions are logical images with original strides.
Concurrent external mutation remains unsupported.

4.10 and 5.0 blend.cpp are identical. Relative to 4.1, SIMD operators become
named intrinsics and VTraits/scalable lanes; OpenCL conversion buffer grows
30->50 with an explicit size. Scalar arithmetic, types, subtractive indexing,
row/parallel geometry and allocation remain materially identical. Core
cvRound gains architecture/builtin choices, not a new portable rounding rule.

An additional exact-header finding: native `CV_CN_MAX` is 512 in 4.1/4.10,
but **128 in 5.0** (CV_CN_SHIFT changes 3->5). Core's public Channel_Count
subtype still extends to 512; the committed Core used here can construct a
128-channel Mat when asked for 512 on 5.0. This binding consumes the actual
Mat metadata and does not redefine Core creation or impose a separate cap.
The maximum-channel test explicitly checks 512 on 4.x and the represented
128 on 5.0. A portable caller must use channel counts valid for its Core/native
environment, not infer allocation representation solely from the Ada subtype.

## Validation-boundary review

Retained public-looking C++ duplicates, each with `ABI safety:` comments:

1. Source_1 not n-D: prevents 4.x publishing an allocated uninitialized result.
2. UInt8 weights 2-D Float32 C1: makes the float-row scan safe and complete.
3. UInt8 weights finite [0,1]: prevents unsafe pre-saturation cvRound conversion.

Width preflight prevents native signed overflow. Nonempty policy, Float32
weight value policy, source compatibility and weight geometry are not
independently duplicated for friendlier C++ diagnostics.

## Validation results and execution boundary

Starting origin/main: `372bfc9aa3c999a8a223881f6845dc4933ac95c6`.
Fresh installed-4.10 baseline: **929 registered/executed/passed**. Final normal
and strict local full suites: **979/979/979**, zero failures/errors. Dedicated
blend suite: **50/50**. No existing operation's implementation was changed.

All project-owned library/test Ada bodies pass `-gnatwa -gnatwc -gnatwu
-gnatwn -gnatwe -gnatyM79 -Werror`. Intentional nonfinite test data uses the
established `-gnatVn` test-closure setting for Core accessors. Production weight
validation locally suppresses validity checks only while classifying foreign
binary32 samples with ordered [0,1] comparisons, so development `-gnatVa`
does not preempt the intended OpenCV_Error. No warning class is suppressed.
The final library also passes strict compilation without `-gnatVn`.

Production C++ passes GCC C++17 `-Wall -Wextra -Wpedantic -Werror` object
compilation; Clang 19 strict syntax checking passes with upstream OpenCV
headers designated system headers (CV_XADD uses the C11 _Atomic extension).
The allocation-free helper passes GCC/Clang strict runs and both compilers'
ASan/UBSan runs. Boundary tests cover exact INT_MAX, boundary+1, malformed
values and each 1..512 channel boundary without allocating giant images.
CI adds the strict helper on Linux/macOS/Windows; Windows dispatch is unchanged.
GNATformat, direct modified-Ada 79-column checks and git diff --check pass.

The entire production shim additionally passes strict syntax checks using
each exact tag's Core/Imgproc public headers, with installed generated header
configuration. This is **source compatibility**, not runtime evidence.

Separate disposable Podman environments execute the complete focused suite:

| Exact runtime | Blend tests | Native maximum-channel fixture |
| --- | --- | --- |
| 4.1.0 | 50/50 | C512 |
| 4.10.0 | 50/50 | C512 |
| 5.0.0 | 50/50 | C128 represented by Core |

These builds use clean committed Core `9bb848f44295929f3858e973ec28f3787891e66b`.
4.1/5.0 execute the exact-tag native Core/Imgproc libraries built for Task 040
(IPP/OpenCL off), not header-only substitutes; 4.10 executes its installed
exact binary. Full production shims compile inside all three environments.
Runtime link inspection confirms the corresponding native sonames. Although
the 5.0 native Core build links its own Geometry library transitively, this
crate adds no Geometry API/dependency or general Core arithmetic dependency.
Exact 4.1/5.0 **full-suite execution was not repeated**: runtime portability
claimed here is this feature's 50 tests, not all existing APIs or architectures.
There is no Float32 cross-architecture bit-identity claim.

GNATprove and coverage were not run: no SPARK-designated code was changed;
foreign arithmetic cannot be proved through this interop boundary. Safety
evidence is widened bounds, pinned source review and behavioral/helper tests,
not a formal proof. Sanitizers cover the helper, not the entire native library.