# Generalized Hough Ballard: preliminary exact-source review

## Status: research only, qualification incomplete

Task 047 starts at fetched main
`20b247efedc7f81d73376b77c3435440a3fc4db8` (merged PR #44).
The isolated worktree is `/tmp/imgproc047-ballard`, branch
`feature/047-generalized-hough-ballard`. The starting open-PR query returned
an empty list. Fresh normal library build succeeded. The normal AUnit runner
reported 1075 executed, 1075 successful, zero failed assertions and zero
unexpected errors; its output contained 1075 `OK` records.

**No Ballard production operation is implemented by this research change.**
No cross-version production-shim corpus has run. No numerical-consistency,
complete native-safety, feature-test, sanitizer, or merge-readiness claim is
made. In particular, this document is not a completed exact-source review:
the remaining dependency-path checks below must precede implementation.

Supported OpenCV installations are trusted external dependencies. Internal
scratch-buffer object-lifetime proofs are not an obligation of this task.
Known signed-overflow and out-of-bounds paths still require protection.

## Exact source provenance

Clean existing local upstream checkouts were verified at these exact tags:

| Tag | Git commit |
| --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

The source roots are `/tmp/imgproc046-upstream-<tag>`.
The 4.1.0 and 4.10.0 complete `generalized_hough.cpp` files have the same
SHA-256, `6e3db6300878790a8ca72364f8b7bd3a285d0f9c1c1dc5304c863ff11f5d1d29`.
The complete 5.0.0 file differs only in a Guil feature-buffer lambda capture,
outside the Ballard path. Its SHA-256 is
`d8638ec92f7485ba9cd34e8d839e895253bea953d5795ea165f7502e818623a9`.
Consequently Ballard source line references below apply to all three tags.
Source identity does not establish preprocessing or runtime-result identity.

Authoritative sources used in this preliminary review:

- `modules/imgproc/include/opencv2/imgproc.hpp`: class declarations, factory,
  Canny and Sobel defaults in each tag.
- `modules/imgproc/src/generalized_hough.cpp`: base preprocessing,
  template/detection overloads, distance filtering, conversion, and Ballard.
- `modules/imgproc/src/canny.cpp`: CPU allocation and arithmetic expressions
  in each tag; 4.10.0 scalar/SIMD nonmaximum suppression and hysteresis bodies;
  public image entry path in each tag.
- `modules/imgproc/src/deriv.cpp`: 3x3 kernel construction and Sobel dispatch;
  4.1.0/4.10.0 share the inspected Sobel entry implementation, while 5.0.0
  removes its OpenVX dispatch.
- `modules/imgproc/src/filter.simd.hpp`: FilterEngine sizing/row processing,
  and 5.0.0's added tiled-filter dispatch and border-copy implementation.
- `modules/core/src/mathfuncs_core.simd.hpp`: scalar `atan_f32` implementation
  in each tag, and `fastAtan2` delegation.
- `modules/core/include/opencv2/core/fast_math.hpp`: 4.10.0 `cvRound`,
  `cvFloor`, `cvCeil` implementation and representability requirements.
- `modules/core/src/matrix.cpp`: Mat allocation in each tag and continuous
  copy-size calculation in each tag.
- `modules/core/src/copy.cpp`: 4.10.0 Mat-to-Mat copy and dispatch; corresponding
  copy-size call sites located in 4.1.0 and 5.0.0.
- `modules/core/include/opencv2/core/hal/intrin.hpp`: SIMD-width definitions.

The remaining exact-version dependency bodies are explicitly listed below.

## Public native declaration and selected configuration

`GeneralizedHough` has image and precomputed-edge/derivative overloads of
`setTemplate` and `detect`. Image-template center defaults to `Point(-1,-1)`;
detect optionally produces votes. `GeneralizedHoughBallard` adds setters for
orientation levels and vote threshold. `createGeneralizedHoughBallard()`
returns a `Ptr<GeneralizedHoughBallard>`.

Class declarations are at imgproc.hpp lines 839/875 (4.1.0), 928/964
(4.10.0), and 913/949 (5.0.0). Factory declarations are at 4178, 4430, and
3804 respectively. Factory annotation changes do not change this signature.
The class comment's wording about translation is misleading: the actual
Ballard implementation searches positions, with scale one and angle zero.

The intended binding selects the image overloads, explicitly sets levels
360, dp 1.0, minDist 1.0, Canny low/high and vote threshold, and passes the
integer center `(Template.Columns / 2, Template.Rows / 2)` explicitly.
The native sentinel is not part of the Ada interface.

## 1. Template preprocessing and R-table

`calcEdges` (110-120) asserts UInt8 C1 and positive ordered Canny thresholds.
It calls Canny with default aperture 3 and L1 magnitude, then separate
Float32 Sobel X/Y with default 3x3 kernels, scale one, delta zero, and
Reflect_101 border. There is no threshold scaling on this selected aperture.
Canny's own derivative calculations use Int16 Sobel with Replicate borders.

`setTemplateImpl` (122-133) records the edge image size and center, then
calls `processTempl` (381-408). The latter allocates `levels+1` bins,
clears every bin, and visits each logical pixel once. A point enters exactly
one bin when its Canny edge is nonzero and either Float32 derivative exceeds
machine epsilon in absolute value. It stores `Point(x,y)-templCenter`.
An all-blank template yields an empty R-table, not an invented detection.

The 3x3 derivative kernels are `[-1,0,1]` and `[1,2,1]`. UInt8 derivatives
are finite integers in [-1020,1020], exactly representable as Int16 and
Float32. L1 magnitude is at most 2040. Canny orientation tests with TG22
13573, `abs(dy)<<15`, and `TG22*abs(dx)+(abs(dx)<<16)` fit signed int
on this derivative domain. These bounds do not apply to arbitrary
precomputed derivatives; that overload is not being exposed.

## 2. Orientation bins and rounding

Template line 403 and Scene line 448 compute
`cvRound(fastAtan2(dy,dx) * (levels / 360.0))`.
With levels 360 the multiplier is exactly one in double precision.
The scalar atan implementation reduces finite inputs to a ratio in [0,1],
uses a bounded first-quadrant polynomial, then applies quadrant corrections.
The native implementation can return or round to 360 near the positive-X
axis from below. Do not replace the table size by 360 or presume `n<360`.
The intended index bound is `0 <= n <= 360`, covered by 361 bins.

Before signing off this bound, complete a rigorous bound on the scalar
polynomial and its floating evaluation, and inspect exact-version scalar
dispatch/rounding paths. Exhaustively checking the selected finite integer
gradient domain against each runtime would provide useful additional evidence,
but would not substitute for inspection of the selected source paths.

`cvRound` is undefined outside signed-int representability. At dp one,
integer displacement centers convert exactly to double and round unchanged.
This statement assumes the normal native floating-point environment.

## 3. Histogram geometry

Line 429 creates Int32 C1 storage with
`cvCeil(imageSize.height / dp)+2` rows and the corresponding width.
At dp one, both original signed-int dimensions are exactly representable
in double, and cvCeil returns them unchanged. Require each Scene dimension
to be at most `INT_MAX-2` before the native additions.

The histogram byte row is `4*(Scene.Columns+2)` and the allocation extent is
`4*(Scene.Rows+2)*(Scene.Columns+2)`. Compute these in widened, checked
arithmetic and bound them by native size/pointer representability. Mat's
auto-step setup accumulates sizes using unsigned/widened arithmetic and
checks size_t conversion, but this does not excuse overflow before create.
`findPosInHist` accesses the one-cell zero halo and rows y, y+1, y+2;
its loops stay inside the created geometry when the additions fit.

## 4. Template displacement and center arithmetic

For one axis with Template dimension T, default center k=floor(T/2),
and Template coordinate q in [0,T-1], displacement d=q-k lies in
`[-k, T-1-k]`. Both endpoints fit signed int for positive signed-int T.
For Scene dimension S and coordinate p in [0,S-1], `c=p-d` lies in
`[k-(T-1), S-1+k]`.

The lower endpoint is no smaller than INT_MIN for positive signed-int T.
A sufficient upper bound is widened `S-1+floor(T/2) <= INT_MAX` for each
axis. This must be checked before line 454, which performs signed Point
subtraction before checking whether the result is inside the Scene.
At dp one no further coordinate growth occurs. An accepted center satisfies
0<=c<S; histogram indices c+1 fit under the geometry bound above.

## 5. Vote-count bound without multiplying image areas

At dp one, distinct Template pixels give distinct integer displacements.
Each enters the R-table at most once and belongs to just one orientation bin.
For a fixed integer center c and a given displacement d, the equation
`p-d=c` has exactly one possible Scene coordinate p. Thus each Template edge
can contribute at most once to that cell. Conversely, for fixed c and p there
is at most one displacement d=p-c; a Scene edge can contribute at most once.

Therefore a sufficient per-cell bound is
`min(Template.Rows*Template.Columns, Scene.Rows*Scene.Columns)`.
Products must be widened before evaluation. Bounding this minimum by INT_MAX
protects the signed increment at line 460, starting from zero. The much larger
Template-area times Scene-area product is not a necessary vote restriction.
This argument relies on dp exactly one; it does not establish a safe domain
for future downsampled accumulators or rotation/scale search.

## 6. Peak selection and output counts

Line 484 reports a cell only when votes are STRICTLY greater than threshold,
strictly greater than its left and upper neighbors, and greater than or equal
to its right and lower neighbors. Document the strict threshold rather than
claiming a detection with exactly threshold votes is accepted.

At most one peak is emitted per Scene pixel. No horizontally or vertically
adjacent cells can both satisfy the peak inequalities. A tighter universal
count bound is `ceil(Scene area / 2)`: pairing adjacent cells along a
Hamiltonian path through the rectangular grid proves at most one per pair,
plus the possible final unpaired cell. This bound is not quarter-area:
diagonally neighboring cells can both be peaks.

`convertTo` (298-320) casts vector size to int and creates 1xN Float32 C4
positions and 1xN Int32 C3 votes, then copies from native vector-backed Mats.
The count must fit signed int BEFORE that cast. The copy helper also forms
`cols*widthScale` in signed int when a flattened byte extent does not fit;
with positions widthScale 16 and votes widthScale 12, N*16 must fit signed
int even when allocation fits size_t. A geometry-only bound on the maximum
N must protect this path before detect; post-detect checks cannot repair
overflow that already occurred in conversion.

Vector capacity/allocation exceptions are ordinary contained native failures.
The maximum vector byte extents and pointer differences still need bounds.

## 7. Positions, votes, empty results, and ownership

Each reported Vec4f is `(float(x), float(y), 1.0f, 0.0f)` (486).
Each Vec3i is `(votes,0,0)` (487). Actual integer votes are component zero
of the Int32 vector, never a Float32 conversion of its count.

Although centers arise on an integer lattice, their native Float32 encoding
cannot represent every integer coordinate above 2^24. The public type is
Float32_Point; do not silently add a new application cap or promise exact
unit-pixel distinguishability outside that representation's precision.

`detectImpl` clears both output vectors before processing. When none are
reported it releases both Mat outputs (171-175); convertTo is called only
for nonempty vectors. Thus the `&vector[0]` operations are not executed on
empty results. minDist exactly one bypasses filterMinDist, including its
sorting/grid allocation and arithmetic paths.

The intended synchronous shim creates a fresh local detector and local
result Mats. It borrows inputs and two output Mat headers through Core's
module bridge; it never destroys or retains any Core handle. Result-type,
length and value checks required for safe Ada decoding precede publication.
Exact input/output header identity and output/output identity must fail
without rebinding either output. Preserve original outputs on any failure.
Core's bridge rejects null handles and temporary external output views;
arbitrary nonnull dangling addresses are not validated by that bridge and
cannot be made safe by a module-level promise to inspect a handle.

## 8. Region isolation design

Always allocate separate owning UInt8 C1 snapshots with original logical
Template and Scene geometry, and copy exactly Columns bytes per logical row.
Check stride, byte extent, pointer representability and positive 2-D geometry
before any pointer formation or memcpy. Copy no parent border pixels.
Both snapshots must finish before detector preprocessing begins.

Sobel normally calls locateROI and may inspect parent pixels. An owning
snapshot has no surrounding parent and an offset of zero, preventing that
behavior from crossing the logical Region boundary. The Canny internal row
subregions may legitimately consult other rows within the private snapshot;
they cannot reach the original caller's Region parent. No copyMakeBorder is
needed. Noncontinuous input strides are honored by the bytewise row copies.
Inputs remain unchanged. Concurrent external mutation is not supported.

## 9. Additional preprocessing geometry obligations

These are correctness/safety restrictions, not application resource caps:

- In all reviewed Canny fallbacks, the map has Rows+2 and a SIMD-padded width.
  4.1.0 uses CV_MALLOC_SIMD128, newer tags use CV_SIMD_WIDTH. Exact headers
  include widths 16/32/64 and a 128-byte scalable-vector bound. Determine
  the supported build's maximum padding and use widened align calculations.
- Bound native `cols+SIMD_width+1`, alignment narrowing, and
  `3*(mapstep+SIMD_width)` before the signed magnitude-buffer expression.
- Bound `(boundaries.start+2)*mapstep` and `boundaries.end*mapstep` before
  Canny forms row pointers. The row additions occur in int, but multiplication
  is promoted to ptrdiff_t because mapstep has that type. Bound the full
  padded-map extent by PTRDIFF_MAX and also account for narrowing the slice
  span to unsigned int pmapDiff. Do not misclassify these multiplications
  as signed-int products or impose an INT_MAX area cap for that reason.
- Bound Sobel destination row bytes, signed FilterEngine strides, padded
  row width, aligned Float32 ring-buffer step, six-row ring indexing, and
  `dststep*i` output batching (i at most six for the selected 3x3 kernels).
- 5.0.0 adds a tiled stateless-filter path for sufficiently large images
  with multiple threads. It forms rounded tile counts and signed byte/row
  offsets. Qualification must include a fixture large enough to enter that
  path without changing global thread settings.
- Ordinary Mat allocation failures are contained exceptions. Do not claim
  memory availability from arithmetic representability alone.

## Remaining gates before production implementation

1. Complete exact 4.1.0/4.10.0/5.0.0 rounding, Mat allocation/copy, derivative,
   filter, scalar angle dispatch and optional backend source-path review.
2. Turn the derived geometry bounds into a checked allocation-free planner,
   with exact accepted/rejected arithmetic-boundary tests and no signed
   overflow in the planner itself. Establish the angle-bin bound.
3. Implement the public Ada, private thin layer and synchronous production
   shim together; add focused AUnit and malformed-ABI/failure-atomicity tests.
4. Run the full deterministic corpus through the actual Core/Imgproc shims
   on exact installed 4.1.0, 4.10.0 and 5.0.0 runtimes. Verify loader paths.
   Compare sorted center/vote sets exactly and preserve all empty results.
5. Add Linux-hosted regressions, README/example, strict compiler checks,
   formatting and scoped sanitizer qualification. Preserve other CI policy.
6. Rebuild and rerun the full suite, inspect the final diff and validation
   boundary, then commit/push and open a non-draft PR only after qualification.
   Stop at independent review; do not merge or enable auto-merge.

## Evidence locations for this research checkpoint

- `/tmp/imgproc047-baseline-build.log`: fresh successful normal build.
- `/tmp/imgproc047-baseline-tests.log`: fresh 1075/1075 AUnit result.
- Known candidate native library directories, not yet qualified for Ballard:
  `/tmp/task040-versions/4.1/native/lib`, `/usr/lib/x86_64-linux-gnu`, and
  `/tmp/task040-versions/5.0/native/lib`.

These temporary paths are local evidence, not reusable harness configuration.
Runtime-equivalence qualification remains **NOT ESTABLISHED**; no fixture
differences have been measured because the production operation is absent.

## Completion record (supersedes the preliminary status above)

The original research commit `4316e24181882d6b4bae1aede01538053e0859b1`
and its preliminary findings are preserved. Main was fetched again and remained
`20b247efedc7f81d73376b77c3435440a3fc4db8`; there were no intervening changes
or conflicting open PRs. The sections above remain historical checkpoint
evidence, not the final feature disposition.

### Safety gate disposition

| Gate | Final disposition |
| --- | --- |
| UInt8 C1, positive 2-D geometry | Established; Ada policy, safe row-copy guard |
| Tiny images | Supported down to 1x1; native corpus covers 25 tiny geometries |
| Canny thresholds | Positive ordered Ada inputs; native raw assertions contained |
| Gradient magnitudes | Int16/Float32 exact integers in [-1020,1020] |
| Orientation indices | Established 0..360; 361 bins, endpoint tested |
| Canny/FilterEngine signed arithmetic | Restricted by derived widened planner |
| Histogram geometry | Restricted to representable padded geometry/byte extent |
| Point displacements | Restricted by S-1+floor(T/2)<=INT_MAX per axis |
| Int32 votes | min(Template area,Scene area)<=INT_MAX |
| Output count/copy width | ceil(Scene area/2)<=floor(INT_MAX/16) |
| Logical Region isolation | Private owning row-copied snapshots |
| Two-output publication | Allocation-free, nonthrowing exact-tag cv::swap |
| Version consistency | Exact corpus agreement, not arbitrary-backend equivalence |

There are no unresolved safety gates in the selected restricted domain.
Trusted native library implementation assumptions remain, including ordinary
allocator/backend correctness; no internal scratch-object lifetime proof is
claimed. No meaningful OpenCV algorithm is reimplemented.

### Completed preprocessing and orientation analysis

The exact Canny image entries and CPU fallbacks in all three tags use aperture
3, L1 magnitude, Replicate Int16 Sobel, and floor of integer low/high thresholds.
Positive Int32 thresholds convert exactly to double; no squaring, division by
16, or range extension occurs in this selected path. IPP's wrapper casts to
float, as native OpenCV normally does, and accepts only C1 UInt8 images with
both dimensions greater than three. Its IwiImage bridge uses native row-step
values; the packed snapshots and planner bound those steps. Tiny images fall
back rather than entering IPP. OpenCL is not selected: inputs/outputs are Mats,
not UMats. The image Canny OpenVX path is disabled; Sobel OpenVX declines
Float32 destinations and declines Replicate on the Canny Int16 derivative
path. HAL and optional optimized backends remain trusted library dispatch.
No global thread, optimization, IPP or OpenCL setting is changed by the shim.

All exact derivative factories build the same integer 3x3 kernels. Float32
intermediates exactly represent the sums/products of these small integers.
The UInt8 derivative bound protects Canny's absolute value, shifts, TG22
products, and L1 sum. Selected borders and positive dimensions allow singleton
axes; no width-one spatialGradient call is involved in this operation.
Scalar/SIMD bounds in Canny process only logical columns and padded map halo.

The public scalar `fastAtan2` in each exact
`mathfuncs_core.dispatch.cpp` uses `CV_CPU_CALL_BASELINE`, not the vector
angle-dispatch family. Its scalar polynomial is the one recorded above.
For c in [0,1], t=c*c, the bracket is
`p1+p3*t+p5*t*t+p7*t*t*t`. It is strictly positive since its lower bound
`p1+p3+p7` is positive. It is at most p1 since
`p3*t+p5*t*t <= (p3+p5)*t <= 0` and p7 is negative.
Thus the first-quadrant polynomial lies between 0 and approximately 57.3
degrees, safely inside [0,90]. Floating evaluation error is many orders
smaller than the positive margin at nonzero reachable gradients; c=0 yields
zero exactly. The alternate branch subtracts that value from 90. Quadrant
corrections yield [0,360], including endpoint rounding; cvRound stays in
0..360. The Emscripten atan2 normalization likewise stays in that domain.
The native corpus additionally exhausts all 4,165,681 integer gradient pairs
in [-1020,1020]^2 against each actual runtime, asserting finite angle, safe
bin and coverage of bin 360. This is stronger testing of the reachable
superset, not a substitute for the source argument.

Exact `fast_math.hpp` bodies were checked in all three tags: double integer
coordinates at dp one fit before cvRound/cvCeil. Differences in instruction
selection do not change these representable integer arguments. Source and
runtime agreement on the corpus does not establish identical intermediates
for every optional native backend.

### Allocation-free planner and arithmetic domain

`cpp/ballard_layout_fits.hpp` uses int64 intermediates. For each input H,W:

- H>0,W>0, H+2<=INT_MAX and W+256<=INT_MAX.
- Canny maximum padded width M=ceil((W+129)/128)*128. Pinned widths are
  16 (4.1's local CV_MALLOC_SIMD128), 16/32/64, or scalable bound 128 in
  newer headers. This envelope covers every reviewed padding alignment.
- 3*(M+128)<=INT_MAX protects the magnitude allocation expression.
- (H+2)*M<=UINT_MAX and PTRDIFF_MAX bounds both row offsets and pmapDiff.
  mapstep is ptrdiff_t in every tag; no invented Int32 row-product cap.
- Float32 filter step B=4*ceil(W/64)*64, B*6<=INT_MAX bounds signed strides,
  ring-row products and output batches. UInt8/Int16 strides are smaller.
- H*W*4<=PTRDIFF_MAX bounds derivative allocation extents. Template-area*8
  also fits PTRDIFF_MAX, covering Point vector storage. Bad allocation still
  fails normally and is contained.
- ceil((W+64)/64)*ceil((H+64)/64)<=INT_MAX conservatively covers 5.0's
  rounded 64/128 tile counts. Dimension bounds cover tile origin/halo sums.
  Tile-local widths/heights are at most 130, so their row/filter products
  remain small; destination signed batch products are bounded by B*6 for
  fallback and actual tile filter loops increment pointers rowwise.

Early short-circuit guards bound W before the large allocation products;
all remaining products fit int64 even for maximum positive signed-int H.
Scene histogram bytes fit PTRDIFF_MAX; their row bytes fit signed int under
the filter-width bound. Template displacement and vote constraints are as
derived above. The Scene peak bound permits at most floor(INT_MAX/16)
outputs, bounding count narrowing, Vec4f allocation and native copy byte width;
Vec3i widths are smaller. This geometry-only restriction is conservative
because a particular image can have fewer peaks; it is tied to native output
conversion, not an arbitrary resource cap. Normal 3840x2160 scenes pass.

The exact Mat create/setSize and standard allocation paths use size_t products
for the reviewed 2-D shapes. The pointer-extent bounds protect those products,
including 5.0's changed MatShape representation. Native vector-to-Mat copy
bodies in all tags use the same getContinuousSize2D width-scale fallback;
the count*16 guard protects the remaining signed width expression and optional
IPP step narrowing. Empty vectors never reach their element-zero address.

Source donor span is checked independently: nonnull data, step>=Columns,
step<=PTRDIFF_MAX, and (Rows-1)<=floor((PTRDIFF_MAX-Columns)/step).
The snapshots copy exactly Columns bytes per logical row and retain no caller
storage. Failure before publication leaves both existing outputs untouched.

Exact `matrix_operations.cpp` cv::swap was inspected in all tags. 4.x swaps
scalar/pointer members and repairs inline step pointers; 5.0 swaps fixed-size
MatShape/MatStep records. Its MatShape copy/assignment bodies only copy scalar
metadata and ten integer slots, with no allocation/assertion/throw. Both final
header swaps therefore cannot fail halfway; old result storage is destroyed
only after both publications. No output header allocation occurs at commit.

### Public API and validation-boundary review

The agreed `Ballard_Template_Match`/array/function are added to the existing
public package. Eight tests cover public success, exact 68-vote decoding,
native integer center, empty bounds, multiple copies, strict threshold,
Canny pairs, Region isolation, input preservation, repeated calls, invalid
types/channels/dimensions/threshold ordering, and raw failure/recovery.
Ada uses Float32_Vec4_Access and Int32_Vec3_Access. The shim verifies scale
one/angle zero before discarding them; Ada checks nonnegative/representable
votes before converting to Natural. Empty outputs return range 1..0.

Retained duplicated conditions and their ABI-safety reasons:

- Nonempty 2-D UInt8 C1: the shim performs bytewise row copies and native
  derivative/edge loops assume this element layout.
- Derived geometry constraints: prevent native signed overflow, unsafe
  displacement subtraction, Int32 vote overflow and output byte narrowing.
- Input/output and output/output identity: prevent rebinding borrowed inputs
  or overwriting one result during two-output publication.
- Native output layout/count/value checks: protect typed indexed reads and
  numeric decoding; fixed scale/angle verification is explicitly required
  by this task's result contract.

Each relevant input guard has an ABI-safety justification in the shim/planner.
Threshold ordering is NOT duplicated in C++; OpenCV safely asserts invalid raw
thresholds and the boundary translates that exception. Null opaque handles
are rejected; arbitrary dangling nonnull opaque addresses are outside the
Core bridge contract, not promised safe. Native boundary tests forge only
geometry on a real Core-owned header and reject it before pixel access.

### Reusable runtime qualification

`tests/ballard_consistency.cpp` includes the production Imgproc shim and links
the real Core shim. It is not an independently implemented detector. Output
records include version, fixture identifier, geometries, exact thresholds,
count, and every native Float32 center/Int32 vote. Sets are sorted without
changing values. Decimal precision 9 round-trips binary32; the Python comparator
uses exact equality, reports every differing fixture and exits nonzero.

`sh tests/qualify_ballard_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500`
supports installed prefixes with package metadata. Preserved source/build
trees can instead supply per-version BALLARD_410/4100/500_INCLUDE, EXTRA,
GENERATED and LIBRARY variables (see script). Each run asserts header
CV_VERSION equals runtime getVersionString and the expected version.
Linux ldd evidence checks both selected libraries load from the requested
library directory; 5.0's geometry/flann dependencies are captured too.
Build metadata and loader evidence accompany each canonical output file.

Actual exact runtime paths:

- 4.1.0: exact-tag core/imgproc headers, generated headers from
  `/tmp/task040-versions/4.1/native`, libraries from its `lib` directory.
- 4.10.0: `/usr/include/opencv4`, `/usr/lib/x86_64-linux-gnu`.
- 5.0.0: exact-tag core/imgproc headers, generated headers from
  `/tmp/task040-versions/5.0/native`, libraries from its `lib` directory.

The 53 deterministic fixtures include blank Template/Scene, identity, rectangle,
asymmetric translation, multiple separated copies, partial visibility, all
four Scene and Template edges, distractors, low/high contrast, all Region
combinations, threshold/Canny changes, 25 small geometries and large 4096x4096
preprocessing. All three versions agree exactly on counts, centers and votes.
Known asymmetric translations are (51,43), (26,32), (125,100), each with 68
votes; native integer template center is (14,15). At threshold 67 the known
match is reported; at 68 it is absent. No numerical inconsistencies observed.
No photographic corpus or arbitrary-backend equivalence claim is made.
The large fixture has 16,777,216 pixels; measured native thread count is 32,
and the reviewed 5.0 size/thread tiled-dispatch gate is satisfied. This verifies
the necessary dispatch conditions without changing global thread settings;
no symbol-level interception of the filter's internal branch is claimed.

Separate allocation-free boundary assertions cover accepted normal 4K,
histogram/dimension rejection, template preprocessing overflow and exact
output-byte boundary: Scene 16384x16383 accepted, 16384x16384 rejected.
Raw tests cover nulls, duplicate/output-input identity, wrong representation,
3-D input, failure-atomicity, forged INT_MAX geometry and recovery. These
large-geometry tests live in the native corpus, not in allocating Ada fixtures.

### Local verification record

- Fresh normal `alr -n build` passes. Full AUnit: **1083 executed, 1083 passed,
  zero failed assertions, zero unexpected errors** (original 1075 preserved).
- Focused Ballard 8/8, Hough 37/37, Canny 5/5, spatial derivatives 11/11,
  spatial gradient 53/53. Full/focused Ada tests use installed 4.10.0; no claim
  of full Ada-suite runs on 4.1.0 or 5.0.0.
- Strict repository Ada units pass -gnatwa -gnatwc -gnatwu -gnatwn -gnatwe
  -gnatyM79 -Werror. A whole-dependency forced strict build encountered three
  existing overlong lines in AUnit's aunit-io.ads (46,47,57); scope was narrowed
  to repository units, without modifying/suppressing checks in dependencies.
- GNATformat applied to added/modified Ada ranges; unrelated formatter edits
  reverted. All modified Ada files pass the 79-column check.
- GCC and Clang 19 strict C++17 production corpus passes against all three
  runtimes using -Wall -Wextra -Wpedantic -Werror.
- GCC and Clang ASan/UBSan production corpora pass against all three runtimes;
  all pairwise corpus comparisons report zero differences. Instrumentation
  covers complete project Core/Imgproc shims and harness, **not** installed
  OpenCV shared libraries. No native-internal sanitizer coverage is claimed.
- `git diff --check` and both shell script syntax checks pass.
- No SPARK-designated code changed; GNATprove was not run. GNATcov was not
  run. Foreign numerical behavior is tested, not formally proved.

Final review and hosted CI remain independent gates; local verification does
not authorize merge. No global OpenCV settings or other module bindings added.