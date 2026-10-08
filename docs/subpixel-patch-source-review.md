# Subpixel patch extraction: Task 043 findings and Task 045 adapter

## Provenance and status

Task 043 research commit `6ff289919c864372d0ac325b7205624af83a6bc2`
on `feature/subpixel-patch-extraction` concluded
`SAFETY_GATE_NOT_ESTABLISHED`. It did not implement a binding. Its findings
are recovered below; this branch starts independently from
`cfa561c361f4ae3038b23dab34dcd4b8f432cb17`, not the research branch.
No research commit is cherry-picked.

The guarded backing-store adapter addresses the historical scalar pointer
defects.
Qualification results are recorded below. The review gate does not authorize
merging or releasing.

## Authoritative exact versions

| Tag | Peeled commit from Task 043 |
| --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Exact-tag source URLs are
`https://github.com/opencv/opencv/blob/<tag>/<path>`.
Task 043 inspected `modules/imgproc/include/opencv2/imgproc.hpp`,
`modules/imgproc/src/samplers.cpp`,
`modules/core/include/opencv2/core/fast_math.hpp`, IPP dispatch headers,
and Core allocation/matrix source. Task 045 rechecked local 4.1 sampler,
fast-math and `modules/core/src/copy.cpp`, and fetched exact 4.10/5.0
sampler, fast-math and copy implementations.

The native declaration is:

```cpp
void getRectSubPix(InputArray image, Size patchSize, Point2f center,
                  OutputArray patch, int patchType = -1);
```

One or three channels are supported. Dispatch supports exactly UInt8 to
UInt8, UInt8 to Float32, and Float32 to Float32. Channels interpolate
independently; Float32 sample values are not required to be finite.

## Historical blockers retained prominently

For an exactly backed 4x4 source, a 3x3 patch centered at (0,0) has integer
origin (-1,-1). `adjustRect` returns `src - rect.x * pix_size`, forming a
pointer before the original allocation. A 1x1 patch centered at (3,3)
forms `src2 = src + src_step` beyond the original allocation before
conditionally subtracting that step. These defects occur in all three
reviewed scalar implementations. Allocation alignment is not a valid
prefix/suffix guarantee. Pointer formation alone need not trigger ASan.

OpenCV is not patched. Border requests never use the caller's backing store.

## Binary32 arithmetic and cvFloor

Both generic and UInt8-to-Float32 paths compute, in float:

```text
adjusted_x = center_x - (width - 1) * 0.5f
adjusted_y = center_y - (height - 1) * 0.5f
ip_x = cvFloor(adjusted_x); ip_y = cvFloor(adjusted_y)
```

For positive signed-int dimensions, the largest rounded float half-window
is 2^30. The largest valid binary32 center below INT_MAX is
2^31 - 128. Subtracting a nonnegative half-window, rounded to binary32,
therefore gives adjusted coordinates in [-2^30, 2^31 - 128]. Neither
endpoint approaches an invalid signed-int conversion. Subtraction cannot
round above the representable center. Floor is also representable; negating
the integer origin is safe. The helper defensively compares widened adjusted
values with INT_MIN/INT_MAX before cvFloor, without changing the computation.

4.1 float cvFloor casts to int then subtracts `(i > value)`. 4.10 also has
floorf builtin and LoongArch paths; 5.0 adds ARM64 paths and a UBSan-disable
annotation. All are safe on the established domain; the annotation is not
used as evidence of safety.

## Direct-safe domain and guards

All origin/sample-bound additions use int64_t. Direct native execution on
Source is permitted only when:

```text
ip_x >= 0; ip_y >= 0
ip_x + width < source.cols; ip_y + height < source.rows
```

Otherwise compute:

```text
Left   = max(0, -ip_x)
Right  = max(0, ip_x + width  - (source.cols - 1))
Top    = max(0, -ip_y)
Bottom = max(0, ip_y + height - (source.rows - 1))
```

The physical parent must have representable signed-int rows/columns.
Each border count then fits int. The helper additionally bounds padded byte
width by INT_MAX: copyMakeBorder uses signed expanded widths and adjustRect
uses signed pixel-byte products. This is an arithmetic boundary, not an
allocation-size preference.

## Isolated parent construction and Core safety model

`opencv_core_mat_copy_make_border` in the current Core shim checks signed
destination dimension additions before `copyMakeBorder`. The adapter reuses
that reasoning and adds the byte-width constraint for the reviewed scalar
copy path. Nonnegative guards and positive source geometry establish the
native preconditions.

`copyMakeBorder_8u` creates border index tables and expands widths/left/right
by its byte-channel count (possibly divided by sizeof(int) in aligned mode).
Bounding full padded byte width bounds the table length, those products, and
the `source.width + i` right-border indices. Replicate chooses bounded source
indices. Mat allocation handles byte-size/allocation failure by exception.

The scalar copy loop advances its source pointer after the last row. For a
bottom-ending, horizontally inset ROI or tightly sized strided external
buffer, that formation need not be inside the original allocation. Border
requests first snapshot Source row-by-row into private continuous storage,
without advancing a caller pointer after the final row, so that final
increment is exactly one-past. Interior requests never snapshot.

The destination loop likewise advances a left-inset pointer after copying
the last logical source row. One extra replicated bottom row ensures that
formation stays inside the padded allocation, including pure horizontal
border requests. The helper rejects padded_rows == INT_MAX before adding
this physical row; this is an adapter representability boundary.

`BORDER_ISOLATED` prevents the `isSubmatrix` branch from expanding Source
into its old parent. Source stride need not be continuous. A new owning
parent is produced by:

```cpp
Mat snapshot(source.rows, source.cols, source.type());
// Copy each logical row by bounded memcpy, with no final pointer increment.
copyMakeBorder(snapshot, padded, top, bottom + 1, left, right,
               BORDER_REPLICATE | BORDER_ISOLATED);
guarded = padded(Rect(left, top, source.cols, source.rows));
```

## Pointer provenance proof

The proof concerns the **underlying private padded allocation**, not an
assertion that arbitrary pointers outside an ROI are valid.

For negative ip_x, native rect.x = min(-ip_x, width), hence
0 <= rect.x <= Left. Returning `src - rect.x * pixel_size` leaves at least
Left - rect.x pixels of physical prefix and remains in the parent.
For nonnegative ip_x, the initial advance stays within the original logical
row. Native adjusted coordinates never exceed Center, so ip_x <= cols-1
and ip_y <= rows-1. Negative rect.width/height pointer-adjustment branches
are therefore unreachable. Their nonnegative subtraction intermediates
are bounded by the padded dimensions when the origin is negative.

Horizontal reads include the floor+1 neighbour through ip_x + width;
the Right guard covers that maximum. The left/right clamping loops index
logical edge pixels, also inside the same allocation. Vertical reads cover
ip_y through ip_y + height. The Top/Bottom guards cover that interval.
When native speculatively forms `src + src_step` at the last logical row,
Bottom is at least one; that pointer is within a physical bottom row,
including any left-prefix offset. Native then clamps as before.
All these offsets are relative to the same owning parent allocation.
The owning padded Mat remains alive through the complete native call.

## Semantic preservation

Native receives exactly the original logical rows, columns, type, Center and
patch dimensions. No translated center is introduced. Native computes
identical adjusted binary32 coordinates, fractions and branch conditions.
Replication only supplies physical storage to make historical pointer
formations valid; native logical nearest-edge clamping remains in control.
There is one native call, with no custom sampler, Remap or Warp substitution.

Generic weights are bilinear. UInt8 output uses cvRound-scaled 16-bit fixed
weights and `(sum + 32768) >> 16`; tests avoid ambiguous half-rounding.
The C1 UInt8-to-Float32 interior specialization clamps horizontal fractional
weight to at least 0.0001f and uses a recurrence. That native behavior is
preserved, not replaced with idealized arithmetic.

Version differences: 4.1 uses assert in adjustRect where 4.10/5.0 use
CV_Assert; error enum spellings are modernized. 5.0 removes unrelated legacy
quadrangle/C wrappers. The reviewed getRectSubPix adjustment, scalar border
arithmetic, supported depth combinations and C1-only IPP dispatch remain
the same. copyMakeBorder retains its isolated-region decision and signed
geometry/expanded-width scalar model across all three versions.

## Signed arithmetic and backend boundaries

C3 needs channel-expanded width bounds. The current helper also reserves
cn-1 for native edge-channel indices (`r.width*cn+c`), and checks nonnegative
origin*cn. This is stricter than width*3 alone because the edge preload
occurs even when a border loop has zero iterations. Guarded byte-width bounds
protect `adjustRect`'s origin/rect.x times pixel_size.

UInt8-to-Float32 origin+patch-size signed additions are checked before native
entry, even if generic fallback would eventually be selected.

IPP dispatch exists only for the three supported C1 depth combinations.
Actual input byte step and fresh output row bytes must each fit INT_MAX.
The guarded input inherits its padded parent's step; direct input retains
Source step. C3 does not acquire IPP-only step restrictions. Installed test
builds observed so far report IPP disabled; no IPP runtime coverage is claimed.

## Publication and validation ownership

The shim resolves borrowed Core headers and rejects exact source/destination
object identity. Distinct destination headers sharing old source storage are
safe because all computation uses local result storage before rebind.
Exceptions are translated by the existing containment mechanism. Publication
is a final move assignment; failures before it leave Destination unchanged.

Duplicated conditions: nonempty 2-D UInt8/Float32 C1/C3 source, positive patch,
finite in-image Center. These are retained for the adapter's ROI construction,
cvFloor domain, typed indexing and pointer-provenance proof, with ABI-safety
comments. Selector checking decodes the ABI. Arithmetic/backend limits belong
in the shim. Friendly public validation remains Ada-owned.

## Verification

Fresh baseline: 1032/1032, no assertion failures/unexpected errors.
Public suite: 38/38; full suite: 1070/1070, with zero failed assertions or
unexpected errors. Adapter-only: 17/17; historical regressions: 2/2.
Existing warp/remap: 48/48; corner analysis/subpixel: 23/23.
GCC and Clang 19 helper and production interception builds pass strict C++17.
Exact 4.1, installed exact 4.10, and exact 5.0 public focused suites each pass
38/38. Each GCC interception run observes 276 calls, 64 direct, 212 guarded.
Both historical tightly backed cases succeed. GCC ASan/UBSan instruments
the complete Imgproc
shim, Core shim and harness, **not the installed OpenCV shared libraries**;
The interception fixtures pass on all three versions. The metadata checks
are essential evidence
in addition to sanitizer silence. Clang 19 strict interception against all
three versions also passes; Clang ASan/UBSan installed-version execution
passes. Both compilers' allocation-free boundary helper sanitizer runs pass.
All three builds report IPP disabled; no IPP runtime coverage is claimed.
The complete production shim is compiled against each exact version as part
of the interception build, with strict C++17 warnings-as-errors.

Modified Ada units compile with -gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
-gnatyM79 -Werror. GNATformat was applied to new tests and modified public
sections; unrelated formatter changes were reverted. All modified Ada files
pass the 79-column check. git diff --check passes. No SPARK-designated
production code changed; GNATprove was not required.