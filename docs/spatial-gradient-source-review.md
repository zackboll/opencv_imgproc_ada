# Portable spatial gradients: unsafe native domain and proven adapter

## Original blocker and research provenance

**Direct native width-one execution is unsafe. The upstream bug is not fixed.**

Task 044 stopped with `SAFETY_GATE_NOT_ESTABLISHED` under its original
borrowed-source-only requirement. All three pinned fallback implementations
unconditionally preload column one, even for width one. Border special cases
protect the first calculation, not that subsequent preload. An exactly sized
one-element buffer gives a concrete one-past-end read. Dead-load elimination
and incidental allocation padding cannot establish defined C++ behavior.

This document recovers the exact-source findings from research-only commit
`cf18e449013bf6bb65538882fedbc685d9b8e558`, branch
`feature/spatial-gradient`, file `docs/spatial-gradient-source-review.md`.
That commit was not cherry-picked or rewritten. Task 044R starts independently
from fetched `origin/main` `f200d8258b2ba777b163e0045909734cf4be12c7`.
The revised policy permits a semantics-preserving private layout adapter.

Binding strategy:

- **Direct native safety domain:** nonempty 2-D UInt8 C1, columns >= 2,
  Reflect_101 or Replicate.
- **Direct native unsafe domain:** columns = 1 on the reviewed fallbacks.
- **Width-one binding domain:** duplicate the logical column into a private
  owning width-two image, execute native once, retain only output column zero
  in fresh owning width-one Mats. Never invoke native at width one.

## Exact pinned evidence

| Tag | Verified upstream Git commit |
| --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Prior review inspected complete `modules/imgproc/src/spatialgradient.cpp`,
`modules/imgproc/include/opencv2/imgproc.hpp`, typed access in
`modules/core/include/opencv2/core/mat.inl.hpp`, allocation/reuse in
`modules/core/src/matrix.cpp`, and universal intrinsics in core's
`hal/intrin.hpp`, `hal/intrin_sse.hpp`, `hal/intrin_avx.hpp`, and
`hal/intrin_neon.hpp`. It also inspected 5.0's `hal_replacement.hpp` and
searched bundled third-party HAL implementations. Task 044R re-read the
review and exact-tag spatial-gradient bodies, specifically tiny heights,
row-pair lookahead, scalar preloads, and SIMD bounds.

| Tag | imgproc.hpp declaration | spatialgradient.cpp unsafe preload |
| --- | --- | --- |
| 4.1.0 | 1688-1690 | 274-279 |
| 4.10.0 | 1797-1799 | 292-297 |
| 5.0.0 | 1547-1549 | 299-304 |

- [4.1.0 exact preload](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/spatialgradient.cpp#L274-L279)
- [4.10.0 exact preload](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/spatialgradient.cpp#L292-L297)
- [5.0.0 exact preload](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/spatialgradient.cpp#L299-L304)

All declarations are:

```cpp
void spatialGradient(InputArray src, OutputArray dx, OutputArray dy,
                     int ksize = 3, int borderType = BORDER_DEFAULT);
```

The bodies assert nonempty CV_8UC1 input, BORDER_DEFAULT or BORDER_REPLICATE,
and ksize = 3. BORDER_DEFAULT equals Reflect_101. They create CV_16SC1
outputs with source geometry. Other borders and BORDER_ISOLATED are not
accepted. Native `_dx.create`/`_dy.create` precede arithmetic and can reuse
matching storage; fresh local output Mats, not arbitrary caller outputs,
are therefore essential for independence and failure atomicity.

## Counterexample retained: width one

```cpp
j = i >= i_start ? 1 : j_start;
j_p = j - 1;
v00 = p_src[j_p]; v01 = p_src[j];
v10 = c_src[j_p]; v11 = c_src[j];
v20 = n_src[j_p]; v21 = n_src[j];
for ( ; j < W - 1; j++ ) { /* ... */ }
```

For H=W=1, all row pointers address the sole pixel, SIMD is skipped, and
j=1 preloads one-past-end before the later loop checks. Core supports valid
exactly sized external UInt8 buffers; this is not malformed input. For Nx1,
the same preload reaches beyond the last tightly packed row. For a Region,
it can instead access a parent column outside the logical image. Padding
the allocation without changing logical width would still leave an invalid
logical sample access in the implementation; this binding changes native
logical width to two and proves the retained output's semantics instead.

## Direct-safe row, loop, and column proof

For positive 2-D H and W>=2:

- H-1/W-1 are representable and nonnegative. H-2 is selected only when H>1.
- Replicate selects top/bottom rows 0/H-1; Reflect_101 selects 1/H-2 for
  H>1. At H=1 both select row zero.
- SIMD enters only for i<H-1: i+1 is valid. Fourth-row i+2 is replaced by
  the bottom border row when i=H-2. The first preceding row uses the top
  border; subsequent i-1 rows are valid. In 4.1 these are lines 138-148;
  4.10 lines 156-166; 5.0 lines 163-173.
- Advancing i by two reaches H for even H or H-1 for odd H, without signed
  overflow, including the signed-int maximum. Scalar i++ reaches H safely.
- For UInt8 vector lane count L, j starts at 1 and enters only for j<W-L.
  Loads at j-1, j, j+1 end no later than j+L<=W-1. Two Int16 stores cover
  the expanded halves at j..j+L-1. W-L and entered j+L are representable.
- SIMD exit j_start lies in 1..W-1. Scalar preloads therefore use valid
  columns, even without vector work. The middle loop bounds j+1<=W-1;
  the right border uses W-2 for Reflect_101 or W-1 for Replicate.
- `Mat::ptr<uchar>(row)` forms data+step[0]*row; the column access still
  needs a valid subscript. The selected rows and columns above supply it.

Consequently 1x2/1xN have valid scalar columns and Y=0; 2x2/Nx2 have valid
preload/right-edge column one and no SIMD column work; 2xN has bounded
row-pair lookahead. No height-specific blocker was found. A two-pixel axis
uses the opposite pixel for both Reflect_101 neighbors; Replicate uses the
edge pixel for its exterior neighbor.

The fallback uses logical rows/cols and stride. It does not call locateROI,
grow the view, or consult parent margins. Direct-path Regions are therefore
logical images, including noncontinuous Regions.

## Formal width-one adapter equivalence and bounded access

Let the original logical pixel at row r be I(r,0). Define private T with
the same H rows and two columns by T(r,0)=T(r,1)=I(r,0). The construction
reads only `Source.ptr<uchar>(r)[0]` for 0<=r<H and writes only T(r,0/1).
It respects arbitrary valid original row stride and never reads a parent
column. T owns its allocation. Native execution receives W=2, which is in
the direct-safe domain proved above.

At original width one, every horizontal border extrapolation for either
supported border maps to the only logical column. Hence the conceptual
three horizontal samples at each of the three neighborhood rows coincide.
At temporary column zero:

| Border | left sample | center sample | right sample |
| --- | --- | --- | --- |
| Replicate | T(r,0) | T(r,0) | T(r,1) |
| Reflect_101 at W=2 | T(r,1) | T(r,0) | T(r,1) |

All entries equal I(r,0). Vertical extrapolation is unchanged: H and the
native border selector are unchanged. Thus all nine samples contributing
to column-zero output equal their conceptual width-one counterparts.

For X, the horizontal derivative coefficients (-1,0,+1) cancel at every
row; X=0 identically. For Y, the horizontal smoothing coefficients sum to
1+2+1=4. With p/n the original vertical border-selected rows,
Y(r,0)=4*(I(n,0)-I(p,0)), exactly the intended 3x3 Sobel derivative.
This proof is independent of observed runtime values or vector/backend
selection; a correct future HAL on width two preserves it as well.

For 1x1, p=n=0 under both borders. The temporary is 1x2, never 1x1;
X=0 by cancellation and Y=4*(I(0,0)-I(0,0))=0. Both cases are tested.

After native success, fresh Hx1 CV_16SC1 results copy only wide_dx(r,0)
and wide_dy(r,0), for 0<=r<H. No wide header or temporary storage is
published. All computations and allocations precede publication. Mat move
assignment releases/rebinds existing headers without allocation; no
potentially failing native/adaptation step remains between publications.
Exact output-header identity and exact source/output identity are rejected;
distinct old output headers sharing pixels remain legal and are rebound.

## Scalar and SIMD arithmetic proof

```text
X kernel: -1  0 +1       Y kernel: -1 -2 -1
          -2  0 +2                  0  0  0
          -1  0 +1                 +1 +2 +1
A=v22-v00, B=v02-v20, C=v12-v10, D=v21-v01
X=A+B+C+C, Y=A-B+D+D
```

Samples are 0..255. Primitive differences are -255..255; successive
intermediates are bounded by +/-510, +/-765, and +/-1020. Both attainable
derivative bounds are **-1020..1020**, within Int16 **-32768..32767**.
Right=255/left=0 attains X=1020; reversing attains -1020. Bottom=255/top=0
similarly attains Y endpoints, including width one.

Scalar UInt8 arguments convert exactly to short; short operands are
integer-promoted before arithmetic. Every scalar intermediate and assignment
back to short is representable. No unsafe product occurs. 4.1 uses vector
operators; 4.10/5.0 use nested v_add/v_sub in the same order. UInt8 expansion
to UInt16 and reinterpretation as Int16 preserves 0..255. SSE/AVX signed
16-bit additions/subtractions use saturating instructions; NEON uses
vqaddq_s16/vqsubq_s16. Every intermediate fits, so no saturation or wrap
is relied upon. Tests independently attain positive and negative endpoints.

## Versions and optional backends

4.1 uses CV_SIMD and compile-time nlanes. 4.10 uses
CV_SIMD || CV_SIMD_SCALABLE and VTraits::vlanes(). 5.0 retains this fallback
and adds CALL_HAL(spatialGradient,...) at lines 116-121. Its default
hal_ni_spatialGradient returns CV_HAL_ERROR_NOT_IMPLEMENTED in
hal_replacement.hpp lines 1425-1433; no bundled third-party implementation
was found in the reviewed tree. There is no IPP/OpenCL dispatch in these
function bodies. SIMD is part of this CPU code, not an IPP/OpenCL backend.
No replacement HAL coverage is claimed.

## Validation ownership and evidence

Ada owns public validation. The shim also retains the task-required raw
source/border checks. Empty/2-D/UInt8 C1 are required for the adapter's own
typed bounded row access; the comments name that concrete reason. Border
decoding recognizes only the two published C ABI selectors (not arbitrary
OpenCV enum/flag values). Native-object identity checks protect borrowed
source ownership and prevent overwriting one result with the other.

Fresh Task 044R baseline: 979 executed/passed, zero failures/errors,
installed OpenCV 4.10.0; Core revision
`9bb848f44295929f3858e973ec28f3787891e66b`. Unlike the historical research
stop, this feature adds public tests and a native interception regression.
The latter compiles the complete real shim and Core shim, uses GNU linker
wrapping to observe every actual native spatialGradient call, requires
width>=2 and exactly one call per valid request, then forwards to the
unmodified installed library. Invalid requests make no native call.
ASan/UBSan instrumentation covers both shims and the harness, not installed
OpenCV libraries. Exact runtime and final count evidence is recorded in the
feature PR; source inspection alone is not claimed as runtime evidence.

### Task 044R measured results

| Exact runtime | Focused AUnit | Adapter subset | Observed native calls |
| --- | --- | --- | --- |
| 4.1.0 | 53/53 | 14/14 | 18, all width >= 2 |
| 4.10.0 | 53/53 | 14/14 | 18, all width >= 2 |
| 5.0.0 | 53/53 | 14/14 | 18, all width >= 2 |

Every run has zero failed assertions and unexpected errors. Native-call
interception also verifies exactly one native call per valid input and no
native call on the exercised invalid raw requests. The 4.1 and 5.0 runtime
executables were built against existing full exact-version installations,
with matching loader paths; the available corresponding Core-only container
images lacked Imgproc and were not usable for those runs. The 4.10 focused
suites ran both locally and in its full image.

Entire production shim strict syntax checks passed with GCC and Clang against
4.1.0, 4.10.0, and 5.0.0 headers using C++17, Wall, Wextra, Wpedantic, Werror.
The native harness built and ran with GCC, and with Clang ASan/UBSan against
all three exact runtimes. GCC ASan/UBSan also passed on installed 4.10.
The instrumentation boundary is both complete project shims plus the test,
not native OpenCV libraries. The harness includes direct two-column, adapted
exact-buffer 1x1/Nx1, and one-column noncontinuous Region cases for both
borders; its independent isolated Sobel oracle excludes parent columns.

Fresh full suite: **1032 registered/executed/passed**, an increase of 53 from
979. Existing Sobel/Scharr 11/11 and Canny 5/5 pass. Strict Ada builds and
the full suite pass with GNAT all-warning/constant/unused/redundant/warnings
as-errors checks (`-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror`).
GNATformat was applied to new files and modified Ada regions, with unrelated
formatter changes removed. No SPARK unit was modified; no formal GNATprove
claim is made. Adapter equivalence and range reasoning above are source-level
mathematical proofs, supported by runtime tests, not machine-checked proofs.