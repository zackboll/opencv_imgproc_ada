# Portable Hit-or-Miss: exact-tag source review

## Evidence and scope

Reviewed authoritative upstream checkouts at these exact tag commits:

| Tag | Commit |
|---|---|
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

For **each** tag inspected:

- `modules/imgproc/include/opencv2/imgproc.hpp`;
- `modules/imgproc/src/morph.dispatch.cpp`;
- `modules/imgproc/src/morph.simd.hpp`;
- `modules/imgproc/include/opencv2/imgproc/hal/hal.hpp`;
- `modules/imgproc/src/hal_replacement.hpp`;
- `doc/tutorials/imgproc/hitOrMiss/hitOrMiss.markdown`;
- `samples/cpp/tutorial_code/ImgProc/HitMiss/HitMiss.cpp`.

Append those paths to each exact-tag source root above. Also inspected 4.x
OpenVX/Carotene morphology registrations and implementation in
`3rdparty/{openvx,carotene}/hal`, 5.0 `hal/carotene/hal`,
`hal/riscv-rvv/{include/imgproc.hpp,src/imgproc/morph.cpp}` and searched
in-tree vendor morphology registrations. These extend, not replace, the
existing ordinary erosion arithmetic review encoded in the morphology bridge.

Local runtime is **OpenCV 4.10.0, Linux x86_64**. Exact-header syntax checks
establish **source compatibility only**, not linkage/runtime execution.
Neither 4.1.0 nor 5.0.0 runtime testing is claimed. Optional HAL vendors were
source-reviewed, not executed locally. No UMat or vendor-disabling policy is
introduced.

## Declarations and tutorial

All three headers expose `MORPH_HITMISS`, documented as supported only for
`CV_8UC1` binary images (4.1 lines 225-227; 4.10/5.0 lines 229-231).
`morphologyEx` retains the same signature/default anchor `(-1,-1)`, one
iteration, Constant border and `morphologyDefaultBorderValue()` in all tags.
That sentinel is `Scalar::all(DBL_MAX)`.

All tutorial samples contain the **same 8x8 0/255 source**:

```
00000000
01110001
01110000
01110100
00100000
00100110
01010010
01110000
```

Here 1 denotes byte 255, not byte 1. The kernel is

```
 0  1  0
 1 -1  1
 0  1  0
```

The tutorial explains background at center, foreground north/south/east/west,
and don't-care corners. Upstream uses `Mat_<int>`; the binding deliberately
uses **Int8 C1**, which preserves -1/0/+1 in the exact native comparisons.
5.0 changes sample construction from comma initialization to initializer-list
syntax, not its data. The independent Ada regression expects only zero-based
**row 6, column 2** to match; its expected image is not another Hit-or-Miss call.

## Identical native operation in all three releases

`morphologyEx` branches at 4.1 line 1215, 4.10 line 1223, 5.0 line 1267:

```
CV_Assert(src.type() == CV_8UC1);
if (countNonZero(kernel) <= 0) { src.copyTo(dst); break; }
k1 = (kernel == 1);
k2 = (kernel == -1);
if (countNonZero(k1) <= 0) e1 = all 255;
else erode(src, e1, k1, anchor, iterations, borderType, borderValue);
if (countNonZero(k2) <= 0) e2 = all 255;
else {
    bitwise_not(src, src_complement);
    erode(src_complement, e2, k2, anchor, iterations, borderType, borderValue);
}
dst = e1 & e2;
```

Thus +1 is a required hit, -1 a required miss and 0 don't-care. Hit-only and
miss-only kernels are valid; missing constraint classes produce neutral 255
legs, not empty masks passed to ordinary erosion. 1x1 +1 yields Source;
1x1 -1 yields its complement, even with the maximum positive iteration count.

The exact 0/255 public contract is deliberate: `bitwise_not(1)` is 254,
**not background 0**. No arbitrary nonzero-to-foreground normalization is
performed. Under 0/255 input, its complement, erosion with neutral/default
or supported reflected/replicated binary borders, and bitwise AND all remain
0/255. Result has Source size/type. No redundant shim postcondition rechecks
that documented behavior.

Native all-zero kernels copy Source. Ada rejects this as a semantically empty
query, consistently with its rejection of empty custom morphology masks.
Malformed Int8 values other than +/-1 become don't-care in native comparison;
Ada's ternary representation is deliberately stricter.

## Anchor, iterations, borders and Regions

The binding calculates explicit `(columns/2, rows/2)`, including even sizes,
and accepts contained nonnegative explicit anchors. Native normalizeAnchor
would implement the same center, but no negative sentinel escapes publicly.
Kernel dimensions may be even and non-square.

Iterations are passed independently to the two erosion legs, **AND once**.
They are not repeated complete Hit-or-Miss transforms. Tests pin full hit and
full miss N=2 and sparse mixed +/-1 N=2/3 behavior.

Both legs receive the **same** `borderType` and `borderValue` above. The bridge
uses the established selector mapping with `BORDER_ISOLATED`, allowing
Constant, Replicate, Reflect and Reflect_101, rejecting Wrap. Constant uses
the native default neutral erosion border (255 for UInt8) on **both legs**;
it is not externally complemented for the miss leg. Edge matches can therefore
be present under default Constant but absent under Replicate. There is no
explicit Hit-or-Miss border scalar overload.

`morphOp` strips the ISOLATED flag and skips `locateROI`, retaining logical
source/destination whole sizes and zero offsets. Parent pixels outside Source
do not participate. The complemented source is newly allocated at logical
size, so it also has no parent participation. Kernel comparisons inspect only
the logical kernel view and produce independent masks. Scan helpers use
`ptr<T>(row)` (honoring step), iterating exactly rows and columns, never parent
extents. Tests compare strided Source/Kernel Regions with clones, use invalid
bytes outside the logical views, and check in-place Region parent preservation.

Native computes both erosion legs before assigning the final AND to dst,
which supports direct in-place operation with the existing borrowed Core
handles. Kernel/Destination overlap keeps the existing custom-morphology
rejection rule. No Mat handle is owned, retained or destroyed by Imgproc.

## Signed arithmetic and shared preflight

Ordinary erosion `morphOp` (4.1 lines 952-976, 4.10 lines 954-978,
5.0 lines 998-1017) first handles the 1x1 copy/no-op, then collapses a
**fully nonzero erosion mask** with N>1 into a rectangle:

```
anchor.x * N
anchor.y * N
width  + (N-1)*(width-1)
height + (N-1)*(height-1)
```

These native expressions use signed int. The shim widens to int64 before
testing representability, including expanded width times channels. The
existing check is extracted to `morphology_expansion_fits.hpp`, shared by
ordinary morphology and Hit-or-Miss; original kernel-area and width/channel
checks, contained anchors, alias rejection and isolated borders are reused
through the same request machinery. Existing operation selectors 0..6 and
UInt8 masks are unchanged; the new private entry point selects native
`cv::MORPH_HITMISS` internally, never through an Ada numeric constant.

For Hit-or-Miss, the full-mask fact is **all_hits OR all_misses**, not
`countNonZero(original_kernel) == area`. Mixed +/-1 full-area kernels produce
**two sparse** masks, neither triggering rectangular collapse. One kernel
scan determines ternarity, any constraint, all_hits and all_misses. The raw
operation independently scans for its safety classification; it cannot trust
facts from an earlier separate caller inspection. Public inspection also scans
Source once and returns exact-binary facts without changing Source.

Allocation-free helper tests use extreme bounds that reject a full mask but
accept sparse classification. An ABI fact test verifies a full-area mixed
+/-1 kernel reports neither all_hits nor all_misses, connecting those bounds
to the actual scan. No huge Mat or INT_MAX sparse-iteration loop is allocated
or executed. Helper tests also pin the 1x1 exemption, width/height/anchor and
expanded channel-width limits, under strict C++ flags and local ASan/UBSan.

## Dispatch, IPP and HAL audit

OpenCL dispatch in both morphologyEx and morphOp requires `_dst.isUMat()`.
The binding borrows **Mat**, not UMat, and retains ISOLATED borders, so it
uses native CPU/HAL Mat paths, not OpenCL. OpenCL-only step casts to int are
unreachable here.

All three files define **IPP_DISABLE_MORPH_ADV 1**; the morphologyEx advanced
IPP invocation is additionally commented out. There is no advanced IPP
Hit-or-Miss call. Each nonempty leg is ordinary erosion and can reach its
ordinary HAL/IPP/CPU paths. The HAL order is replacement HAL, ordinary IPP
when available, then OpenCV filter engine. 5.0 first attempts a new stateless
morphology HAL callback before the existing context init/apply/free model.

Public HAL declarations and default replacements pass image/kernel steps as
**size_t**, dimensions/anchors/counts as int; default callbacks return NOT
IMPLEMENTED. Generic morph SIMD code computes `ksize*cn`, `width*=cn` and
`pt[k].x*cn` in signed int (4.x morph.simd lines 120/121, 502/515, 661-672;
5.0 121/122, 505/518, 667-679). Shared original/expanded width-channel and
kernel-area checks protect these expressions. Hit-or-Miss never sends an
empty erosion mask into MorphFilter's `&coords[0]`/`kp[0]` path.

4.x OpenVX accepts centered odd C1 single-iteration erode with Constant or
Replicate, rejects oversized kernel dimensions and in-place/submatrix use,
copies logical mask rows with size_t steps, and handles the DBL_MAX erosion
sentinel as 255. It has native image-dimension/stride adaptation. Carotene
(4.x thirdparty, 5.0 hal) accepts supported UInt8, full masks, one iteration,
adequate dimensions and no submatrix/in-place path, honors anchor/border and
logical ROI margins, and translates default erosion border to UCHAR_MAX.
These vendor paths may be reachable for appropriate decomposed erosion legs;
the binding does not claim to disable all vendors or test them locally.

**Optional OpenCV 5.0 RVV limitation:** its registered 3x3 UInt8 C1/C4,
single-iteration erosion path has additional upstream hazards not cured by
the existing generic bridge review: `std::vector<uchar> dst(width*height*cn)`
uses signed area arithmetic; default erosion border initialization performs
`static_cast<uchar>(DBL_MAX)` before only special-casing dilation. These are
vendor-specific source findings, not a claim of RVV runtime safety. RVV is
not part of the tested x86_64/ARM64/Windows environments. This focused slice
does not modify existing Erode/Dilate semantics, patch upstream, or introduce
vendor-dispatch controls. Deployments enabling that exact optional backend
need separate upstream/backend validation. IPP older-version stride checks
remain native; no new shim stride narrowing is added.

## Validation boundary (task clarification)

Ada owns public semantic policy: binary bytes, ternary values, at least one
constraint, source/kernel domain, contained explicit anchor, border and alias
contracts. `hit_or_miss_inspect` supplies five 0/1 facts, not semantic error
statuses. It checks only the handles/output pointer and byte/2-D layout needed
for its row pointer scans, clears fact output before failure and contains all
exceptions. No thresholding, normalization or meaningful algorithm is Ada.

`hit_or_miss` independently enforces native/ABI safety before native execution:
borrowed handle resolution, two-dimensional byte layouts, selectors, positive
iterations, safe geometry/expansion, anchor bounds, supported border and
kernel/output overlap. Preflight failures preserve output metadata, pixels
and storage identity. Arbitrary forged/dangling pointers are not supported
Core handles; no claim is made that dereferencing such pointers is safe.

Raw C callers are **not** guaranteed public Ada semantic rejection: nonbinary
UInt8 pixels retain native results; malformed-but-safe Int8 values use native
comparison; all-zero kernel retains Source copy. Small raw tests pin this
distinction and recovery. Ordinary all-zero UInt8 masks still reject for the
separate existing MorphFilter empty-coordinate safety reason.

Retained semantic-looking duplicates have concrete ABI reasons documented
inline: 2-D byte layouts for row indexing/scans; raw Source CV_8UC1 rejection
before morphologyEx creates/rebinds dst and only then asserts its source type;
anchors for pointer offsets; dimension products and full-mask
expansion for signed native arithmetic. Kernel/output overlap protects a
borrowed kernel while native output may rebind/write its storage. Binary,
ternary and semantically-empty-query rejection are **not duplicated** in C++.

## Verification scope

25 focused AUnit registrations extend baseline **812** to **837**. Coverage
includes tutorial location, independent binary results, each missing-leg
branch, don't-care invariance, anchors/even sizes, full and sparse iterations,
Region isolation/step, in-place preservation, borders, exact public errors,
raw safety/atomicity/recovery and native semantics outside the public contract.
No SPARK-compatible unit is materially changed: these foreign-call wrappers
are runtime-checked/tested, not formally proven; GNATprove/GNATcov are not
claimed. Strict builds, formatting and exact-header checks are recorded in
the feature/PR validation report; dependency metadata remains untouched.

## Local verification results

- Full AUnit: **837 registered, 837 executed, 837 passed**, zero failed
  assertions and unexpected errors; baseline 812, new focused registrations 25.
- Project-owned Imgproc library and test Ada units force-compiled with
  **-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror** using
  Alire-managed GNAT 16.1.0/GPRbuild 26.0.1. No new suppressions or warnings.
- Production shim object compilation and arithmetic helper:
  **-std=c++17 -Wall -Wextra -Wpedantic -Werror**, PASS. Helper also executed
  locally with ASan/UBSan, PASS. No sanitizer dependency was added.
- Final shim syntax-check against the exact public Core/Imgproc headers at
  all three pinned commits above: PASS. Installed generated module metadata
  was used for header configuration; algorithm declarations came from each
  exact tag. This proves source compatibility, not runtime testing of 4.1/5.0.
- GNATformat on all changed Ada plus check mode: PASS; direct 79-column
  check: PASS; `git diff --check`: PASS.
- Normal `alr -n build` and `alr -n -C tests run` succeeded locally. Alire's
  known pkg-config/sudo deployment blocker occurred on an intermediate
  invocation; fallback used `scripts/configure_opencv.sh` and discovered
  Alire-managed compiler/project paths without dependency changes.
- Final strict builds/link and full suite also used clean detached Core
  **36c2791aedb3fab3f3b585651f7b92666feb5528**, because sibling Core acquired
  unrelated work. That work was left untouched. Core was built under its own
  **release** policy, not Imgproc's extra strict flags. An initial detached
  Core development-profile build enabled float validity checks that rejected
  existing NaN/Inf fixtures in 18 unrelated tests; rebuilding Core with its
  release profile restored the established full-suite behavior (837/837).
  All project-owned test and library units retained the requested strict gates.