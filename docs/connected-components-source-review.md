# IMGPROC-API-002 — connected components completion

## Baseline and scope

Freshly fetched `origin/main`: **0fe5162ba47f91c8b54e66356e9ec9d037ce29dd**
(merged PR #73). Working tree was clean; no matching remote branch or PR
existed. Feature branch: `feature/imgproc-api-002-connected-components`.
No release/index changes, merge or auto-merge are authorized.

Reviewed existing public specification/body, internal C imports, C header/shim,
`connected_component_tests.adb`, `Connected_Component_Set`, `Component_Label`,
`Background_Label`, `Component_Statistics`, `Get_Component`, overlap validators,
Core 0.4.1 Module_Interop and `opencv_core_module_bridge.hpp`. Core owns all Mat
headers/storage. Handles are callback-scoped borrows, never retained. Regions
are distinct reference-counted headers; shallow copies share pixels but not
headers. Output resolution rejects non-rebindable temporary external views.
Core controlled assignment allocates a new wrapper during Adjust: new label
publication therefore uses an internal, nonallocating native header swap, not
controlled Ada assignment.

## Authoritative upstream review

Exact tags reviewed in the local authoritative OpenCV Git mirror and exact-tag
source trees: **4.1.0, 4.6.0, 4.10.0, 5.0.0**. For every version:

* `modules/imgproc/include/opencv2/imgproc.hpp`: ConnectedComponentsTypes,
  ConnectedComponentsAlgorithmsTypes, both `connectedComponents` overloads,
  both `connectedComponentsWithStats` overloads and attached documentation.
* `modules/imgproc/src/connectedcomponents.cpp`: dispatch, NoOp, CCStatsOp,
  union/flatten operations, Wu/Grana scans and parallel stripe allocation;
  Bolelli 8C/4C serial/parallel paths where present, and 5.0 overflow guards.

Permanent sources:

| Tag | Header | Implementation |
| --- | --- | --- |
| 4.1.0 | [header](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/include/opencv2/imgproc.hpp) | [CCL](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/connectedcomponents.cpp) |
| 4.6.0 | [header](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/include/opencv2/imgproc.hpp) | [CCL](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/connectedcomponents.cpp) |
| 4.10.0 | [header](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/include/opencv2/imgproc.hpp) | [CCL](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/connectedcomponents.cpp) |
| 5.0.0 | [header](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/include/opencv2/imgproc.hpp) | [CCL](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/connectedcomponents.cpp) |

Additional header availability checks through the GitHub contents API: 4.2.0,
4.3.0, 4.4.0, 4.5.0, 4.5.1 have only WU/GRANA/DEFAULT; **4.5.2** introduces
BOLELLI, SAUF, BBDT and SPAGHETTI. This avoids an incorrect `minor >= 5` gate.
Intermediate releases are source-availability checks, not runtime qualification.

### Exact declarations and output contracts

Every requested tag has labels-only `(image, labels, connectivity, ltype)` and
`(image, labels, connectivity, ltype, ccltype)`, and statistics equivalents with
`stats, centroids` inserted before connectivity. Defaults are 8 and CV_32S;
the short overload delegates to CCL_DEFAULT. All return int N including label
zero, with labels in `[0,N)`. Both CV_16U and CV_32S are native output formats.
Source channels must be one; native code accepts 8U or 8S, while the public Ada
contract deliberately accepts only UInt8. Zero is background, any nonzero byte
is foreground. Labels have Source geometry, stats are N x 5 CV_32SC1, centroids
N x 2 CV_64FC1. The background row exists even with no background pixels; its
centroid is not a meaningful foreground value and is never converted to Ada.

Labels-only uses NoOp: it does not compute statistics. Statistics store min/max
coordinates, signed pixel area and uint64 coordinate integrals; finish produces
width/height and double centroids. Ada excludes row zero and preserves exact
foreground label IDs as Get_Component indexes. No independent renumbering.

| Version | Default 8C / 4C | SAUF | BBDT | Spaghetti |
| --- | --- | --- | --- | --- |
| 4.1.0 | Grana / Wu | CCL_WU | CCL_GRANA | explicit error |
| 4.6.0 | Bolelli / Bolelli4C | CCL_SAUF | CCL_BBDT | CCL_SPAGHETTI |
| 4.10.0 | Bolelli / Bolelli4C | CCL_SAUF | CCL_BBDT | CCL_SPAGHETTI |
| 5.0.0 | Bolelli / Bolelli4C | CCL_SAUF | CCL_BBDT | CCL_SPAGHETTI |

BBDT 4C dispatches to Wu in all reviewed versions. SAUF documents row-major
ordering; BBDT/Spaghetti do not. Native default is passed unchanged. In early
Spaghetti-capable intermediate releases native Spaghetti 4C dispatches to SAUF;
the binding delegates to the selected native selector, not a replacement.

## UInt16 capacity strategy and arithmetic argument

**Never call native CV_16U CCL in the new operations.** Old LabelT lunique,
parent indexes, flatten counters and nLabels are ushort on that path. They can
wrap during the first pass before a final component count exists; a final-count
check or assuming merged final components fit does not protect parent accesses.
5.0 adds overflow checks, but portable safety does not depend on those additions.

All new calls label privately into CV_32S. Before execution the shim checks:

* positive 2-D geometry (native row-zero access is otherwise unsafe);
* rows/columns and pixel product at most `INT_MAX - 2`;
* allocation/pointer-offset representability, source row stride at least the
  addressed row size and `rows * step <= PTRDIFF_MAX`.

Pixel product is evaluated in uint64. Wu parallel stripe offsets include
`row * width` (4.1 adds one before division); Grana/Bolelli allocate
`ceil(h/2)*ceil(w/2)+1`; Wu/Bolelli4C use `ceil(h*w/2)+1`. The pixel bound
conservatively bounds these provisional IDs, sentinel increments, `h+1/w+1`,
two-row stripe rounding, signed area accumulation and int statistics indexing.
Centroid sums are bounded by pixels times a coordinate, below uint64 capacity.
Memory representability is bounded separately for the largest per-label rows.
Native allocation exhaustion still translates through the error boundary.

After execution, verify positive N, N <= pixels+1, metadata before typed access,
and **every label** nonnegative and < N. UInt16 additionally requires N <= 65536
and every ID <= 65535. Only then convert to a fresh CV_16U Mat. Rejection occurs
before publication; the old destination and all aliases are untouched.

Memory/performance: Int32 staging is four bytes/pixel plus native working sets,
with a full label-validation scan. UInt16 publication temporarily adds two
bytes/pixel and conversion cost. No direct UInt16 fast path is claimed.

### Proven unsafe 4.1 paths

1. Parallel Wu/Grana allocate `h` chunk entries but access `startR + 1` /
   `i + 1`. An odd final stripe can address element h. Reject odd-height input
   when `getNumThreads() > 1 && rows / getNumThreads() >= 2`. The native
   framework query is not public in 4.1, so this intentionally also rejects
   builds with that thread gate but no active parallel backend.
2. CCStatsOp::finish unconditionally computes `INT_MIN - INT_MAX + 1` for an
   absent background's width/height. **Observed with instrumented 4.1 OpenCV**.
   New statistics calls reject all-nonzero UInt8 sources on 4.1 before native
   CCL. Labels-only calls remain supported. No synthetic background is added.

At IMGPROC-API-002 the legacy entry point was left unchanged. IMGPROC-SAFE-003
below closes those remaining safety gaps while retaining direct storage reuse.
No global thread/optimization changes.

## Public API and publication

Two new strong types: Connected_Component_Algorithm and
Connected_Component_Label_Depth. New Connected_Components has defaults for
connectivity, Int32 depth and native default. New statistics overload requires
Label_Depth before optional Connectivity/Algorithm; existing positional/named
legacy calls retain their identity.

Ada validates source semantics and exact byte overlap with Source. Native
temporary results are passed into private Core-owned Mats. Ada validates
geometry/depth, statistics shape, foreground bounds, positive area and finite
centroids before numeric conversions and building Connected_Component_Set.
Components assignment completes before the final label header swap. Out
parameters are unspecified on exceptions under Ada semantics. Source pixels,
old label aliases and destination Region parents are never written. Source
Regions honor their strides and exclude parent pixels outside the view.

## Validation-boundary review

Retained semantic-looking duplicate guards and their concrete safety reasons:

* Identity and overlapping storage: prevent publishing several results through
  the same/overlapping borrowed objects; protect source and output isolation.
* Empty/2-D/positive shape: native scans access row zero and signed dimensions
  before useful dimensional assertions.
* Signed geometry/pixel/stride limits: prevent native signed arithmetic overflow,
  invalid allocation sizes and unrepresentable pointer offsets.
* 4.1 odd parallel height: prevent out-of-bounds chunk metadata access.
* 4.1 no-background statistics: prevent proven native signed bounds overflow.
* Returned count/shape/label ranges: required before typed row access, narrowing
  conversion and publication. Statistics shape protects subsequent Ada indexing.

These guards have `// ABI safety:` comments in the shim. Invalid selector checks
are C ABI decoding, not a second public integer API. Depth/channels rely on native
assertions for raw callers; public UInt8 C1 policy remains Ada-only. All potentially
throwing exports contain exceptions; diagnostics remain thread-local. As with
Core's bridge, arbitrary dangling/forged pointers are not made valid handles by
this API; tests use real Core wrappers and documented null/invalid output states.

## Qualification and reproducibility

Native harness: `sh tests/run_connected_components_native.sh`. Select an exact
installation through PKG_CONFIG_PATH and OPENCV_TEST_PACKAGE (opencv5 for 5.0).
Use OPENCV_CORE_TEST_PREFIX for indexed Core 0.4.1; SANITIZE=1 instruments both
production shims. Instrumented native libraries were also used locally for all
four versions. UBSan halts on error; ASan halts and checks leaks. Native reference
calls are independent direct OpenCV calls, using Int32 rather than unsafe native
UInt16. Controlled checkerboards independently establish capacity/counts.

| Version | Native comparisons | Counted expected rejections | ASan/UBSan |
| --- | ---: | ---: | --- |
| 4.1.0 | 1998 | 1605 | clean after explicit unsafe-path gates |
| 4.6.0 | 3592 | 15 | clean |
| 4.10.0 | 3592 | 15 | clean |
| 5.0.0 | 3592 | 15 | clean |

Counts include both labels-only and statistics; malformed ABI checks are
additional, not misrepresented as registered AUnit tests. Harness covers
null/aliased outputs, invalid selectors, empty/N-D/wrong-type sources, overflow,
signed dimension/product and stride boundaries, rejection atomicity and recovery.
Source ROI/background patterns, thin dimensions and tall serial/parallel images
are compared pixelwise, including statistics and populated centroids.

Registered AUnit baseline **1147**, after **1156** (+9); connected-components
suite **6 -> 15**. Tests compare partitions instead of arbitrary numeric IDs,
check SAUF ordering, statistics by actual label, Region-local coordinates,
destination rebinding, source preservation, aliases and 65536/65537-label limits.
Full **1156/1156** runs passed against each requested native version. Version
switches used forced release rebuilds to avoid stale profile artifacts; one
earlier mixed-profile 4.6 run failed unrelated NaN-input tests and was not
counted as qualification. The clean release rebuild passed without weakening
any test. Installed 4.10 root `alr -n build` and `alr -n -C tests run` pass.

GNATdoc: **317 -> 321 declarations**, **187 -> 189 subprograms**,
**1534 -> 1556 documented items**, **276 categorized names**, zero warnings and
100% coverage. Existing declaration identities/empty ratchets remain enforced.
Frozen historical shadow authority/evidence is unchanged.
All **177 documentation/mutation tests** pass. After advancing the immutable
identity baseline to the actual starting main (317 identities), the affected
26-test coverage suite was rerun successfully. Five guide executables and the
landing-page example build and run. CI configuration controls: 50 tests run,
48 pass and two existing environment-dependent controls skip; skips are not
platform qualification. `git diff --check` is clean.

GNAT 12 actual source-unit controls pass in Debian containers for x86_64 and
AArch64 with real indexed Core specifications. These are compile-only controls,
not full GNAT 12 production or target-runtime qualification. Hosted Linux/macOS,
Debian installed-consumer and cross controls remain required PR checks. Windows
remains post-merge/manual, not a skipped-job pass. No independent reviewer has
approved this feature yet; stop at independent review, leave PR unmerged with
auto-merge disabled.
The complete production C++ shim also compiles warning-free to an ELF64
little-endian AArch64 object with GCC 12 and real OpenCV headers. No SPARK proof
claim is made: this path uses controlled Mats, foreign callbacks and Ada-owned
vectors; safety evidence is explicit runtime checks, native source analysis,
native sanitizers and behavioral tests, not GNATprove.

## IMGPROC-SAFE-003 — legacy statistics hardening

### Baseline and compatibility

Starting `origin/main`: **6a8c0f4c3c9a195a77699f184e9de2554f1d3b5f**,
the merge commit of PR #74 (merged 2026-10-18T17:42:06Z). Fetched before work;
clean tree, no duplicate safety branch or open PR. Branch:
`safety/003-legacy-connected-components`.

The legacy Ada declaration and C symbol/signature are unchanged. The call still
uses the short native `connectedComponentsWithStats(..., connectivity, CV_32S)`
overload, hence **native default**, not a selected substitute. It still writes
directly into the caller's Labels: matching Int32 C1 storage is reused, including
shallow aliases and a destination Region's parent. It is deliberately NOT routed
through the newer private staging/publication path. Components still contains
only foreground records indexed by actual label. No ownership changes, extra
public declarations, thread-setting changes, synthetic pixels or relabeling.

### Exact upstream evidence

Re-reviewed exact-tag headers and implementations in the authoritative local
OpenCV Git mirror; SHA-256 of each local `connectedcomponents.cpp` matched
`git show <tag>:modules/imgproc/src/connectedcomponents.cpp` byte for byte.

| Tag | Upstream commit | Statistics / dispatch / chunks |
| --- | --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` | [init/finish L101–156](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/connectedcomponents.cpp#L101-L156), [Wu chunks L594–640](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/connectedcomponents.cpp#L594-L640), [Grana chunks L2541–2575](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/connectedcomponents.cpp#L2541-L2575), [dispatch/wrappers L3926–4031](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/connectedcomponents.cpp#L3926-L4031) |
| 4.6.0 | `b0dc474160e389b9c9045da5db49d03ae17c6a6b` | [finish L146–164](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/connectedcomponents.cpp#L146-L164), chunks `roundUp(h,2)` L1143,1772,2302,4243; dispatch L5622–5769 |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` | [finish L146–164](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/connectedcomponents.cpp#L146-L164), chunks/dispatch as 4.6 above |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | [finish L146–164](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/connectedcomponents.cpp#L146-L164), rounded chunks L1155,1785,2318,4267; dispatch L5652–5799 |

1. **4.1 odd parallel chunks:** short statistics overload L4009–4012 delegates
   to CCL_DEFAULT; L4023 constructs CCStatsOp. The same dispatch gate L3939
   selects parallel Wu for 4C and Grana for default 8C. Wu allocates h ints
   (L598), writes `startR+1` (L367,446), reads `i+1` (L618,629). Grana rounds
   stripe starts upward (L841–844), allocates h ints (L2545), writes `startR+1`
   (L1879), reads `i+1` (L2564). A final single-row stripe can address h.
   Reject **odd rows AND threads > 1 AND rows/threads >= 2**, exactly the newer
   conservative public thread gate, for BOTH legacy connectivities. No public
   backend query exists in 4.1; backend-inactive builds may also be rejected.
2. **4.1 absent background:** init L110–114 leaves zero-area row 0 with INT_MAX
   minima and INT_MIN maxima. Finish L148–149 unconditionally subtracts them,
   overflowing signed int before Ada can discard background statistics. Reject
   **all-nonzero C1 8U OR 8S input**, before native labeling. Native L3936 accepts
   both depths and instantiates uchar scans; public Ada still permits only 8U.
   Zero detection uses the source view, not its parent, and honors row stride.
   Other types/channels are left to safe OpenCV assertions. 4.6/4.10/5.0 finish
   tests `area > 0` before bounds subtraction and initializes the absent row
   otherwise; their chunk arrays are rounded up. Neither 4.1-only gate applies
   to those newer versions.
3. **Signed native arithmetic:** the Wu `row*width+1` stripe offset L393 and
   L629, Grana `(h+1)/2,(w+1)/2` parent allocation L2541, stripe round-up,
   provisional parent/sentinel increments and CCStatsOp signed area L139/179
   require positive 2-D geometry and rows/cols/pixels <= INT_MAX-2. Product is
   computed in uint64 before native execution. This bounds provisional indices
   and coordinate sums; pointer/allocation representability is separately
   bounded by `pixels <= PTRDIFF_MAX/(5*sizeof(double))`, conservatively covering
   stats/centroid/integral rows. Allocation exhaustion remains an exception.
4. **Strides/extent:** native Wu L305–308,407–409 and Grana L853–859 use row
   pointers and one/two-row byte offsets. Shared preflight verifies row bytes,
   packed element step, `step[0] >= cols*elemSize`, `rows*step <= PTRDIFF_MAX`
   and addressed extent `(rows-1)*step+row_bytes <= dataend-data` without pointer
   arithmetic overflow. These checks precede even the absent-background scan.
   Valid noncontiguous Regions remain supported. Existing nonempty 2-D outputs
   are checked too, since native create may reuse them. N-D outputs may safely
   be rebound; N-D sources cannot reach 2-D scans. Arbitrary forged/dangling
   handles or lying backing-storage metadata are not supported by Core's ABI.
5. **Ownership/aliasing:** native labels create precedes CCStatsOp init, whose
   output create/getMat calls retain shallow headers. Shared output headers or
   intersecting byte storage can therefore corrupt another result or unread
   source during direct writes. Check all six source/Labels/Stats/Centroids
   pairs for identity and exact row-byte overlap, including cross-depth views.
   This does not reject aliases of Labels that are NOT another argument: they
   still observe successful writes. OpenCV Core's `Mat::create` early return
   for matching geometry/type preserves that contract; ROI headers own a
   reference, not an independent pixel allocation. No borrowed handle is owned,
   retained or destroyed by Imgproc.

### Error boundary and validation-boundary review

One private native preflight is reused by legacy and newer operations. It
returns established invalid-argument status/diagnostic; thick Ada raises
OpenCV_Error. The raw count is initialized to zero before handle resolution.
All preflight rejections preserve Source, output headers and previous storage;
Components is an Ada out parameter and is **not** promised preserved on error.
Later direct native/allocation failures have no new rollback guarantee.

Retained duplicated conditions are specifically ABI safety: empty/2-D/positive
geometry prevents native row-zero access; signed dimensions/product prevent
native overflow and invalid parent indexing; stride/extent checks prevent
out-of-bounds reads/writes; identity/byte-overlap checks prevent destructive
cross-output/source writes; 4.1 thread/height prevents chunk OOB; absent
background prevents signed stats overflow. Each is annotated `// ABI safety:`.
Depth/channel tests in the 4.1 guard select **all native-accepted representations
of the hazardous operation**, not a duplicate UInt8-only public policy.
Connectivity checks decode the C selector. No new semantic postconditions.

### Reproduction and qualification

The normal native harness now runs a legacy corpus with independently computed
short-overload native references, 1/2 threads (restored by RAII), both
connectivities and native byte depths, thin/even/odd/tall shapes, four masks,
strided Regions and direct destination ROI/shallow aliases. Malformed checks
cover null count/handles, all six identical and overlapping argument pairs,
cross-depth overlap, invalid selectors/types, empty/N-D, signed geometry/product,
short/overflowing/out-of-allocation strides and output stride rejection/recovery.

Separate opt-in **unsafe native-only** reproductions (never normal regression
calls) are `tests/bin/connected-components-4.1.0-1 --unsafe-41-background` and
`--unsafe-41-chunks`, after building with instrumented 4.1 and `SANITIZE=1`.
The first reproduced UBSan signed overflow at upstream L148; the second (17x32,
2 threads, default 8C, with background) reproduced ASan heap-buffer-overflow
at Grana FirstScan L1879, immediately past the 68-byte h-entry allocation.
A preliminary 513-row 4C schedule did not reproduce an error; no universal
schedule-dependent crash claim is made. Both public paths reject before CCL.

### Qualification results

Starting registered AUnit was **1156/1156**. After the two legacy cases it is
**1158/1158**, with zero failed assertions and zero unexpected errors, against
OpenCV 4.1.0, 4.6.0, 4.10.0 and 5.0.0. The 4.10 run used installed opencv4 in
`/usr/lib/x86_64-linux-gnu`; 4.1, 4.6 and 5.0 used their exact local prefixes.
Version switches were clean release rebuilds.

| Version | Comparisons | Counted rejections | Legacy references / rejections | ASan/UBSan |
| --- | ---: | ---: | ---: | --- |
| 4.1.0 | 1998 | 1605 | 560 / 374 | clean on guarded calls |
| 4.6.0 | 3592 | 15 | 896 / 38 | clean |
| 4.10.0 | 3592 | 15 | 896 / 38 | clean, including the installed library |
| 5.0.0 | 3592 | 15 | 896 / 38 | clean |

Malformed ABI and recovery checks passed on every version and are not counted
as registered AUnit tests. The opt-in unsafe 4.1 reproductions still fault
upstream: UBSan signed overflow at L148, and ASan heap-buffer-overflow at
Grana FirstScan L1879 for the recorded 17x32 8-connected case.

GNATdoc 26.0.0 regenerated with zero warnings. Coverage remains **1556/1556**
(100%), **321** declarations and **189** subprograms; both baselines stay
empty. The added safety text is in the opening description so it renders with
the declaration. Documentation tests were rerun by module against that site:
comment-only 6, coverage 26, warning comparison 36, navigation 11, type links 23, validation
43, guides 14, shared-shadow 10 and applicability 8; all passed. The combined
discovery command was not retained as one process. Hosted Linux/macOS, Debian
installed-consumer, Windows and full production cross execution were not rerun
and are not claimed as passed. Debian 12 GNAT 12 source-unit controls passed
compile-only: native x86_64 was rerun for this change (4 tests), and AArch64
passed in the earlier container run (4 tests). The host `gcc-12` lacks
`gnat1`, so that local rerun is not qualification. The host CI-control attempt
ran 54 tests with 6 failures caused by that same missing `gnat1` and 2 skips.
The Debian container CI-control run passed (54 tests, 2 environment-dependent
skips); the skips are not platform qualification.
No independent reviewer has approved this correction. Do not merge, enable
auto-merge, tag or release.

Historical IMGPROC-API-002 counts above remain historical evidence and are not
reused as evidence for this correction.