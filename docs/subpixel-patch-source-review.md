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
width by INT_MAX: adjustRect uses signed pixel-byte products. The existing
reviewed byte-width boundary is retained. This is an arithmetic boundary, not an
allocation-size preference.

## Corrective review: Float32 aliasing and bytewise parent construction

Reviewed head `0db89b2a64d53053e38c84b3e603d6f6b8baacd7` used a private
snapshot followed by copyMakeBorder. Exact 4.1/4.10/5.0 copyMakeBorder_8u
selects intMode for four-byte-aligned pixel sizes, strides and pointers.
It casts source/destination to `const int*`/`int*` and accesses them through
those types. Float32 C1/C3 representations do not establish ISO C++17
type-based aliasing permission for those accesses. IPP, compiler behavior
and sanitizer silence cannot establish that permission.

The correction removes copyMakeBorder and the separate snapshot entirely
from this adapter. It allocates `Mat(guard.rows + 1, guard.columns, type)`
and uses only uchar row pointers and memcpy. No source-value floating-point
arithmetic or incompatible typed loads occur during padding. Full pixel
representations (including signed zero, infinities and NaN payloads) survive.
OpenCV itself is not modified; native getRectSubPix still does the sampling.

Let P=elemSize, W=columns*P, S=source.cols*P, F=left*P.
The checked plan bounds W by INT_MAX and guard.rows+1 by INT_MAX, so these
size_t products are representable. Before horizontal pointers are formed,
the shim checks P<=W, F<=W-P, S<=W-F, W<=padded.step, S<=source.step,
and right*P==W-(F+S). Source is nonempty, so S>=P. Thus the first donor F
and last donor F+S-P each have P bytes inside the row. For 0<=x<left,
x*P+P<=F; for 0<=x<right, F+S+x*P+P<=W. All copies are disjoint.

Logical source row r is obtained only for 0<=r<source.rows; destination
top+r is below top+source.rows<=guard.rows. Each logical row copy reads
exactly S bytes from the logical Region, not its parent. Horizontal guards
read only the now-initialized first/last pixels. No caller row pointer is
incremented after the last row.

Vertical copies read fully initialized rows top and top+source.rows-1.
Destinations 0..top-1 and top+source.rows..padded.rows-1 are distinct from
those donors and entirely within the allocation. Copy length is W, not a
stride that might include unrelated storage. Every physical pixel, including
the extra final bottom row, is initialized. No negative offsets or pointers
outside the allocation are formed. Mat allocation exceptions are contained.

The extra bottom row and existing planner boundaries remain unchanged.
The original-size ROI is constructed only after all padding succeeds.
Region isolation is structural: only logical rows/pixels are read; no
copyMakeBorder parent expansion or BORDER_ISOLATED dependency remains.

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
the same. The historical copyMakeBorder implementation is reviewed as the
reason for this correction, not a production dependency of this adapter.

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
38/38. Corrected interception observes 308 calls, 64 direct, 244 guarded.
There are 16 added Float32 C1/C3 representation fixtures (two calls each),
including noncontinuous Regions, all guard directions, oversized patches and
1x1 images. Every physical pixel is checked byte-for-byte against a clamped
logical donor before native forwarding, including the extra bottom row.
Fixtures include positive/negative finite values, both zeros, both infinities
and explicit quiet NaN payloads 0x7fc12345 and 0xffc54321. No interpolation
output payload/signed-zero preservation is asserted.
Both historical tightly backed cases succeed. GCC ASan/UBSan instruments
the complete Imgproc
shim, Core shim and harness, **not the installed OpenCV shared libraries**;
The interception fixtures pass on all three versions. The metadata checks
are essential evidence
in addition to sanitizer silence. Clang 19 strict interception against all
three versions also passes; Clang ASan/UBSan execution passes on all three
versions. Both compilers' allocation-free boundary helper sanitizer runs pass.
All three builds report IPP disabled; no IPP runtime coverage is claimed.
The complete production shim is compiled against each exact version as part
of the interception build, with strict C++17 warnings-as-errors.

Modified Ada units compile with -gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
-gnatyM79 -Werror. GNATformat was applied to new tests and modified public
sections; unrelated formatter changes were reverted. All modified Ada files
pass the 79-column check. git diff --check passes. No SPARK-designated
production code changed; GNATprove was not required.

Correction validation leaves all existing Ada tests intact: 38 focused,
17 adapter, 2 historical on each exact version; 1070 full-suite tests.
No Ada source changed in the corrective delta; existing project-owned units
were strictly recompiled and the focused Ada formatter/79-column checks run.
Linux hosted CI now runs both sanitized guard arithmetic and the complete
native interception regression after normal Imgproc tests. ELF wrapping is
not added to macOS/Windows; Windows manual-dispatch policy is unchanged.

Validation-boundary review: new byte-extent/guard checks protect memcpy
offsets and lengths, not public semantic policy. Existing duplicated source
geometry/type and center/patch prerequisites remain for typed native indexing,
ROI construction, cvFloor and allocation-provenance bounds, as documented
above. No additional public semantic validation is duplicated by this correction.