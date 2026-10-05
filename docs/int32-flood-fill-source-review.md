# Portable native Int32 flood fill: exact-source review

## Pinned evidence

Reviewed complete `modules/imgproc/src/floodfill.cpp` in these exact tags:

| Tag | Commit |
| --- | --- |
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Also reviewed each tag's `modules/imgproc/include/opencv2/imgproc.hpp`,
`modules/core/src/array.cpp` (`scalarToRawData`), and Core headers
`fast_math.hpp`, `saturate.hpp`, and `matx.hpp`. The public header describes
8-bit/floating images, but the implementation explicitly supports **CV_32SC1
and CV_32SC3** in both equality and gradient dispatch in all three versions.
Both public overloads, defaults, flags, and borrowed Mat usage are unchanged.
This binding deliberately exposes those native Int32 paths, not a substitute
algorithm, Float32 conversion, normalization, or clamping.

## Simple versus gradient paths

4.1 evaluates `is_simple = mask.empty() && !MASK_ONLY` before constructing
an internal mask. Zero differences (technically below `DBL_EPSILON`) and a
different replacement value can select `floodFill_CnIR<int>` or
`floodFill_CnIR<Vec3i>`. Otherwise it falls through to gradient execution.
4.10 and 5.0 create and initialize the mask **before** testing `mask.empty()`;
even the no-mask overload therefore reaches gradient execution. There is no
portable zero-range exemption from gradient arithmetic.

## Signed subtraction and the chosen safety rule

All three sources define `Diff32sC1 = DiffC1<int>` and
`Diff32sC3 = DiffC3<Vec3i>`. `DiffC1` computes `int d = a[0] - b[0]`.
`DiffC3` computes `Vec3i d = *a - *b`; `Matx_SubOp` evaluates
`a.val[i] - b.val[i]` in signed int **before** `saturate_cast<int>` (which is
identity for an int). Thus saturation does not prevent signed-overflow UB.

Before either native overload, scan the logical image, without modifying it,
and require independently for each channel:

```
int64(maximum stored value) - int64(minimum stored value) <= INT_MAX
```

Every possible original-sample difference is then in `[-INT_MAX, INT_MAX]`.
This covers both neighbour references in floating range and the saved seed
reference in fixed range, including 8-connectivity and C3 components. Native
gradient traversal marks pixels before queueing, skips masked candidates,
and repaints a segment only after exploring its neighbouring segments. The
reference row is still original while it is explored; already repainted
pixels are not used for later difference comparisons. `New_Value` therefore
need not be included in the stored-value span. Equality execution has no
sample subtraction. The same conservative scan applies to mask-only and
zero-range requests, and does not simulate traversal or discount obstacles.

The exact boundary `INT_MAX` is safe; `INT_MAX + 1` and the full endpoint span
`4294967295` reject. A Region scans only its logical pixels, using its actual
parent stride; pixels outside it are irrelevant. This is a **native safety
boundary**, not a mathematical flood-fill policy. Disconnected extrema may
conservatively reject. Preflight rejection precedes image/mask mutation and
native mask-border initialization.

## Scalar conversions and other Int32 arithmetic

`scalarToRawData` uses `scalarToRawData_<int>` for CV_32S, converting active
components with `saturate_cast<int>(double)`, which calls `cvRound` and does
**not** saturate. The documented conversion domain is finite
`[INT_MIN, INT_MAX]`; accept that closed interval, including both endpoints.
`cvRound` selects SSE, x87, `lrint`, ARM instructions, or a fallback
`int(value +/- 0.5)`. The fallback's truncation still represents both exact
endpoints. Non-half fractional inputs round normally; half ties can differ
by backend/rounding environment and are not pinned to architecture-specific
expected values. Inputs outside the documented interval are rejected even
if a particular backend happens to return an integer sentinel.

Int32 lower/upper differences are converted with `cvFloor` in all tags.
4.1 truncates to int then subtracts `(i > value)`; 4.10/5 add built-in or
architecture floor paths with the same documented finite conversion domain.
For public nonnegative differences the accepted interval is `[0, INT_MAX]`.
Fractional differences are retained and **floored by OpenCV**, not rounded
or required to be integral. `DiffC1`/`DiffC3` negate the floored lower bound;
this is representable because the bound is nonnegative and <= INT_MAX.
Unlike the UInt8 difference classes, the Int32 classes do not add lower and
upper bounds or sum pixel channels. No further active Int32 sample arithmetic
occurs (the accumulation snippet is commented out).

Mask-only execution still calls `scalarToRawData(newVal)` upstream. The Ada
API already substitutes zero for its ignored New_Value; the raw shim also
substitutes zero so an ignored invalid value cannot trigger conversion UB.
Inactive Scalar components remain irrelevant. Ada owns finite/nonnegative
public policy; duplicated conversion-domain checks in the shim protect raw
callers from undefined conversions, not diagnostic friendliness.

## Coordinates, strides, area, buffer, and masks

`FFillSegment` stores y/l/r/prevl/prevr in unsigned short, direction in short.
Keep the existing <=65535 dimension guard, including the `R+1` sentinel.
The initial buffer count is `2 * max(width,height)` (signed multiplication
before size_t assignment). Existing dimension limits make it representable.
Growth uses size_t `size()*3/2`; active segments are bounded by image pixels,
and existing int area/stride bounds also bound storage on supported 32/64-bit
targets. Vector allocation failures stay inside exception translation.

Area accumulates segment lengths in signed int; existing `rows*cols <=
INT_MAX` protects it. 4.1 narrows image and mask byte strides to signed int
and multiplies them by row coordinates; 4.10 uses size_t strides and 5.0
uses ptrdiff_t strides. These routines can form neighbouring-row pointers
before checking border mask bytes; that is pre-existing native pointer
behavior, not an Int32 sample-arithmetic fix or a proof of all pointer UB.
Preserve the existing widened product checks for real image/mask strides and
the private `(rows+2)*(cols+2)` mask. C3 adds 12 bytes per pixel, but performs
no separate unguarded signed whole-image byte product. Row scanning uses
native typed row access and bounded columns/channels, not packed-buffer
assumptions. Existing overlap rejection protects comparison data from mask
writes. No Core handle ownership changes are necessary.

The mask is UInt8 C1, two rows/columns larger than Image. 4.1 sets the border
with memset and side writes; 4.10/5 use isolated constant copyMakeBorder.
All set the outer border to 1, skip nonzero interior pixels, and write the
selected nonzero mask-fill byte to accepted pixels. Mask-only suppresses
image assignment, but still performs sample comparisons and updates area,
bounds and mask. Existing explicit masks must be nonempty for portable
header behavior: 4.1 uses a temporary for empty masks, newer versions create
the caller's mask. No new semantic mask/type/geometry policy is added in C++.

## Backend and validation boundary

The floodFill entry points dispatch directly to these CPU templates. There
are no IPP, HAL, OpenCL, OpenVX, or vendor flood-fill algorithm dispatches in
any reviewed source. Generic mask initialization/copyMakeBorder is not an
alternative Int32 difference implementation. No claim about arbitrary
vendor replacements of the OpenCV binary is made.

## Validation results

Starting main: `291ea23ed4b02914850af454622a9c9f9786d681`.
Fresh installed-4.10 baseline: **905 registered/executed/passed**. Final local
suite: **929/929/929**, zero failures/errors; **24 new Int32 registrations**.
Standalone Int32 plus unchanged segmentation runner: **59/59**. Exact typed
Int32 access verifies endpoint replacements and near-endpoint samples,
INT_MAX span acceptance, INT_MAX+1/full-domain rejection, image/mask
preservation, logical Region isolation, and recovery. No floating observation
is used to compare stored endpoints. Public Result is assigned on success
only (no valid Result promised after exception); raw rejected outputs are
zeroed before native mutation.

All project-owned Ada bodies pass `-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
-gnatyM79 -Werror`. Tests use the established `-gnatVn` workaround for
intentional NaN/Infinity validation inputs; production Ada does not need it.
GCC compiles production C++ with `-std=c++17 -Wall -Wextra -Wpedantic -Werror`.
Clang 19 strict syntax checks pass with OpenCV headers designated system
headers (otherwise upstream CV_XADD's C11 `_Atomic` extension warns).
The allocation-free span/conversion helper passes GCC and Clang strict runs,
and both compilers' ASan/UBSan runs. CI executes it on Linux/macOS/Windows
without changing Windows dispatch policy. Changed Ada passes GNATformat
(range-scoped for the large library body), direct 79-column checks and
`git diff --check`.

Existing exact-version Podman environments execute the suite with a clean
Core checkout at `9bb848f44295929f3858e973ec28f3787891e66b`. The 4.1 and 5.0
images originally contained Core only: exact-tag Core/Imgproc were built
inside disposable containers with IPP/OpenCL disabled, not substituted by
headers or a newer binary. 4.10 uses its installed exact 4.10.0 library.

| Exact OpenCV | Int32 | Int32 + segmentation | Full suite |
| --- | --- | --- | --- |
| 4.1.0 | 24/24 | 59/59 | 927/929; existing Bayer EA and UInt16 Otsu failures |
| 4.10.0 | 24/24 | covered in full suite | 929/929 |
| 5.0.0 | 24/24 | covered in full suite | 929/929 |

All three builds compile the full production shim against their exact
public headers. The native safety review does not claim full-suite 4.1
portability beyond this feature. No unrelated Bayer/Otsu fix is included.
Rebuilding untouched starting main in that same exact 4.1 environment gives
**903/905**, with exactly the same Bayer EA assertion and UInt16 Otsu OpenCV
exception. Thus final 927/929 adds 24 passing tests and no new 4.1 failures.
The local sibling Core has an unrelated test-file modification; container
validation uses committed clean Core, and this task never modifies Core.

GNATprove/coverage were not run: no SPARK-designated code is changed and the
material safety preflight is native C++. GNATprove would not prove native
traversal or foreign casts. The span implication is a widened integer bound;
foreign behavior is established by pinned review and focused runtime tests,
not claimed formal proof. Sanitizers cover the helper, not all native OpenCV.

Validation-boundary review: new C++ layout selectors protect typed scan
access; span guards prevent signed sample overflow. The retained duplicates
of public finite/conversion limits protect raw `cvRound`/`cvFloor` from
undefined conversions, each documented with an `ABI safety:` reason.
Nonnegative difference policy remains Ada-only; raw negative finite values
are rejected by OpenCV. No new duplicate public depth/channel/mask geometry
policy, numeric type code, or Int32-only C export is introduced.