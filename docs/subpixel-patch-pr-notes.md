# Add safe portable subpixel patch extraction

## Starting point and provenance

Actual freshly fetched main: cfa561c361f4ae3038b23dab34dcd4b8f432cb17.
Fresh baseline: 1032 registered/executed/passed, zero failures/errors.
Task 043 research commit 6ff289919c864372d0ac325b7205624af83a6bc2
stopped at SAFETY_GATE_NOT_ESTABLISHED because scalar border paths form
out-of-allocation pointers. Its findings/probe are recovered and expanded
in this coherent feature commit, not cherry-picked as separate history.

## Implementation and proof

Public Extract_Subpixel_Patch uses Float32 Center and Core Mat ownership.
UInt8/Float32 C1/C3 are supported, with optional UInt8-to-Float32 promotion.
Positive patches may exceed Source. Invalid public input raises OpenCV_Error.

Native binary32 adjusted origin is reproduced exactly. Its range is
[-2^30, 2^31-128], inside portable cvFloor signed-int conversion bounds.
Direct execution requires nonnegative integer origin and origin+patch-size
strictly below logical columns/rows on both axes. Interior does not snapshot.

Border requests compute int64 guards:
L=max(0,-ip_x), R=max(0,ip_x+width-(cols-1));
T=max(0,-ip_y), B=max(0,ip_y+height-(rows-1)).
All individual counts and padded dimensions are preflighted.
Private bytewise construction replaces the reviewed head's snapshot and
copyMakeBorder call. The aligned int-pointer copyMakeBorder fallback in all
three pinned versions cannot establish C++17 aliasing permission for Float32
storage. Logical rows, horizontal donor pixels and vertical donor rows are
copied only with uchar pointers and memcpy, preserving complete representations.
The existing extra initialized bottom row and arithmetic bounds remain.
The original-size ROI is exposed to getRectSubPix without translating Center.

rect.x <= -ip_x <= Left contains the historical prefix subtraction.
Bottom contains speculative src+step; horizontal/vertical sample ranges
through ip+patch-size stay in the owning padded allocation. Center inside
Source makes negative rect.width/height branches unreachable. Provenance is
the parent allocation, not an assumption that any out-of-ROI pointer is safe.
Logical dimensions, type, Center, patch size, branch selection and binary32
weights remain unchanged. No custom sampler, OpenCV patch or Remap fallback.

Signed C3 expanded width and neighbour-channel indices are bounded;
Guard construction/adjustRect byte products are also bounded. UInt8-to-Float32
signed origin+width/height additions are checked. C1 actual input step and
output row bytes fit IPP signed int. C3 has no IPP-only step restriction.
All runtime builds report IPP disabled: no IPP runtime coverage claim.

Regions are isolated. Surrounding parent changes do not affect output.
Raw ABI identity is rejected; shared old storage in distinct destination
headers is accepted. Local computation precedes final move publication.

## Verification

- Focused public suite: 38/38 on exact 4.1.0, 4.10.0, 5.0.0.
- Adapter subset: 17/17; historical top-left/bottom-right: 2/2.
- Existing warp/remap: 48/48; corner/subpixel: 23/23.
- Final full AUnit: 1070/1070, zero failed assertions/unexpected errors.
- Normal alr build and alr -C tests run pass.
- Modified Ada compiles with -gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
  -gnatyM79 -Werror. GNATformat applied; modified Ada 79-column check passes.
- Strict GCC/Clang C++17 helper/interception builds pass with
  -Wall -Wextra -Wpedantic -Werror.
- Entire production shim compiled against exact 4.1/4.10/5.0 headers.
- Corrected interception: 308 native calls, 64 direct, 244 guarded;
  both exactly backed historical regressions succeed through private guards.
- GCC and Clang ASan/UBSan interception pass on all three versions.
  Both helper sanitizer runs pass.
- Sanitizer boundary: full production Imgproc shim, Core shim, helper/harness
  instrumented; installed OpenCV shared libraries NOT instrumented.
  Native metadata interception, not sanitizer silence alone, checks backing.
- git diff --check passes. No SPARK-designated production changes.

Retained duplicated conditions are ABI safety prerequisites: nonempty 2-D
UInt8/Float32 C1/C3 for typed row access/ROI creation; positive patch and
finite in-image Center for cvFloor/index/provenance bounds. Specific reasons
are documented in production comments and the source review.

Review gate only. Do not merge or release. Windows remains manual-dispatch.

## Corrective delta for PR #43

Previous reviewed SHA: 0db89b2a64d53053e38c84b3e603d6f6b8baacd7.
One normal corrective commit retains that feature commit as its parent.
Public API, binary32 arithmetic and native interpolation are unchanged.
Before forwarding, interception compares the complete private extent against
clamped Source donor bytes, including the extra row. Sixteen new Float32
C1/C3 fixtures cover signed zeros, infinities and explicit quiet NaN payloads,
single-sided/all-sided guards, Regions and an oversized patch on 1x1 Source.
Source/parent preservation and failure atomicity now use byte comparisons.
Linux-only CI adds sanitized guard arithmetic and native interception steps.
macOS and Windows policy is unchanged. Independent delta and exact-head CI
review are required; this is not a merge-ready declaration.