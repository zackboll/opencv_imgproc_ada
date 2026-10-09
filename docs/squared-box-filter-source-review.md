# Squared box filtering: source review and qualification

## Revised Task 046 assurance boundary

The user explicitly revised the earlier assurance contract: supported OpenCV
installations are trusted external dependencies. This policy decision, not a
repair or disproof of the scratch-storage concern, permits production work.
All earlier findings and the historical `SAFETY_GATE_NOT_ESTABLISHED`
disposition below remain evidence under the earlier stricter contract.

**Accepted upstream dependency assumption:** OpenCV's internal FilterEngine
scratch-buffer object-lifetime implementation is treated as part of the
supported third-party library implementation. In particular the reviewed
`std::vector<uchar>` numeric-object-lifetime concern remains an accepted upstream
implementation assumption; it has not been formally disproved or repaired.

**Binding-owned obligations:** all public preflight, native-call geometry,
border adaptation, signed arithmetic, ownership, and output publication remain
validated. Known native out-of-bounds paths and signed overflow are NOT accepted.

### Production architecture and arithmetic argument

The thick Ada API validates nonempty 2-D UInt8/Float32 C1/C3, positive kernels,
the four supported borders and effective kernel area using widened arithmetic.
The thin private C_API borrows Core Mat handles. The production shim uses the
existing allocation-free layout plan and shifted bytewise adapter, then calls
native `cv::sqrBoxFilter` once with Float64 destination, `(0,0)` anchor and
Replicate native border. A cloned crop publishes fresh original-size storage
only after success. Source/destination native-object identity is rejected;
distinct headers sharing storage can safely be rebound. Exceptions are contained.
The shim maps module border constants (Reflect_101 = 3) to OpenCV values
(Reflect_101 = 4); the research planner uses OpenCV border values.

The effective kernel is computed from ORIGINAL logical geometry: normalized
nonconstant singleton axes reduce to one; sum and constant modes do not.
Normalized Constant singleton axes with effective dimension >1 expand native
logical geometry to at least two, preventing unwanted native reduction.
All outputs are cropped to the original geometry; extra native columns/rows
are trailing and do not change accumulator history of preceding outputs.

For effective dimensions kw,kh and expanded native nw,nh, the owning parent is
`(nw+kw-1) x (nh+kh)`, including the extra bottom guard row. Physical `(x,y)`
is copied bytewise from original local coordinates `(x-kw/2,y-kh/2)`, using the
requested border or zero for Constant. Periodic mapping is widened and bounded.
The native input ROI starts at the parent's `(0,0)`, with horizontal trailing
halo kw-1 and vertical trailing halo kh plus the guard. Thus dx1=dx2=0,
native initial y is nonnegative, and its final unconditional source increment
stays in the allocation. Neither the incompatible horizontal typed-border-copy
branch nor synthetic constant-row filtering is used. No copyMakeBorder is used.

The plan bounds effective area by INT_MAX (33025 for UInt8), channel-expanded
widths, border lengths, source/output byte widths, kh+3, 2*(kh-1)+1,
64-aligned ring-buffer widths, buffer steps and signed row-pointer products,
output batch step products, and padded dimensions. Source row stride and its
last donor extent are separately bounded before pointer formation. Allocation
extents fit PTRDIFF_MAX. Each target offset x*pixel_bytes is within its row;
each donor sx/sy is within the original logical Region. Widened intermediate
products fit int64: rejected signed-int factors are bounded before multiplying
allocation extents. Allocation failure is translated, not an arbitrary ceiling.
The UInt8 accumulator bound remains 33025*65025 = 2147450625 <= INT_MAX.

### Predeclared consistency and independent correctness policies

`tests/compare_squared_box_outputs.py` defines these limits BEFORE measurements:

* A, UInt8 sum: exact numerical equality (all representable integer sums).
* B, UInt8 mean: at most 2 binary64 ULP, covering reciprocal rounding followed
  by multiplication rounding; no general-purpose absolute epsilon floor.
* C, finite Float32: at most 4 ULP, a small evaluation-rounding agreement budget,
  not a bound relative to large unrelated samples. Tiny residual losses cannot
  hide behind a loose relative tolerance.
* D: matching finite/NaN/signed-infinity classification; finite results use C.
  NaN payloads and signed zero are not public contracts.

The corpus exports exact binary64 bits and complete fixture/output metadata.
It compiles the REAL production Imgproc and Core shims. The independent window
oracle separately tests ordinary and bounded Float32 inputs and UInt8 inputs;
UInt8 sums are exact, other oracle comparisons use a 64-epsilon rounding budget
relative to the bounded sum (the public Ada UInt8 oracle uses 2e-15).
This oracle tolerance is not the cross-version agreement policy.

Native incremental Float32 arithmetic differs from exact local arithmetic.
For `[2^40,1,-2]` and kernel 1x1 it can yield `[2^80,0,3]` rather than
`[2^80,1,4]`. Tiny residuals after large samples may be lost; subtractive updates
are cancellation-sensitive despite positive squares. Nonfinite state can
persist beyond the ideal window; Inf-Inf can turn subsequent outputs into NaN.
The corpus retains these cases without sanitization, ideal-accuracy assertions,
integral substitution, widened tolerances or dropping an input class.
The top `[2^40,2^40,2^40]`, bottom `[1,1,1]`, 3x1 Constant sum counterexample
is included explicitly by pattern 5; this is native squared box, not integral.

### Repeatable qualification

From the repository root, with exact-tag installed prefixes:

```sh
sh tests/qualify_squared_box_versions.sh /path/to/4.1.0 /path/to/4.10.0 /path/to/5.0.0
```

Each prefix must have include headers, libraries and lib/pkgconfig metadata.
The command strictly builds the production shim against each installation,
executes the identical corpus, captures version-labeled results and compares
every value pairwise, returning nonzero for unapproved differences. For build
trees, `run_squared_box_consistency.sh` also accepts OPENCV_TEST_INCLUDE,
OPENCV_TEST_EXTRA_INCLUDE, OPENCV_TEST_GENERATED_INCLUDE, OPENCV_TEST_LIBRARY,
OPENCV_TEST_PACKAGE and PKG_CONFIG_PATH. CXX selects GCC or Clang; SANITIZE=1
instruments both full production shims and the corpus, NOT prebuilt OpenCV.

Hosted Linux CI runs the production corpus and arithmetic regression against
its distribution installation; it does NOT provide exact-version comparison.
Existing Linux/macOS/manual-Windows event policies are unchanged. There are no
additional exact versions pinned in this repository's compatibility section.

### Measurements (Linux x86_64)

Exact 4.1.0, 4.10.0 and 5.0.0 production runs: 3857 cases and 62753 values EACH.
All three pairwise comparisons: zero unapproved inconsistencies. For EACH
class A/B/C/D, maximum finite absolute difference = 0, relative difference = 0,
ULP difference = 0; all nonfinite classifications agree. No unexplained
discrepancies. This is direct measured agreement, not just independent passes.
No bitwise promise is made for arbitrary compilers/architectures/installations.

Runtime libraries: 4.1 uses /tmp/task040-versions/4.1/native/lib; 5.0 uses
/tmp/task040-versions/5.0/native/lib (including its geometry dependency);
4.10 uses /usr/lib/x86_64-linux-gnu. Exact-tag headers were taken from the
preserved /tmp/imgproc046-upstream-* checkouts; generated headers from each
native build. These OpenCV libraries are Release, NOT sanitizer-instrumented.
The GCC/Clang strict C++17 corpus and GCC ASan/UBSan runs instrument only the
production shims/corpus when enabled. See final qualification record for checks.

### Final local verification record

Fresh starting baseline: 1070 registered/executed/passed at starting main
499e963333c446f1e87e29b93314ced126ec0599. Expanded public AUnit suite:
1075 executed, 1075 passed, zero assertions/errors (OpenCV 4.10.0).
The five focused tests contain parameterized oracle, four type/channel families,
all modes/borders, singleton/even/oversized geometry, Region/ownership,
invalid-input/recovery and exact signed-area-boundary checks.
The separate production-shim native corpus checks raw ABI nulls, identity,
invalid dimensions/mode/border/representations, failure atomicity and recovery.
Linux ELF interception verifies actual native invocation, effective dimensions,
explicit anchor, private ownership, safe halo/guard geometry, and no native call
for invalid requests. It forwards to the real native algorithm, not a replacement.

`alr -n build`, `alr -n -C tests run`, and `git diff --check` pass.
Strict Ada compilation through the tests Alire environment used -gnatwa,
-gnatwc, -gnatwu, -gnatwn, -gnatwe, -gnatyM79, -Werror; no warnings.
GNATformat was applied to changed Ada; unrelated formatter changes reverted.
Modified Ada files satisfy the 79-column check. Strict GCC and Clang 19 C++17
builds used -Wall -Wextra -Wpedantic -Werror. Arithmetic helper ASan/UBSan passes.
GCC production corpus ASan/UBSan passes on ALL three exact native versions;
Clang ASan/UBSan passes on 4.10. The full Core/Imgproc shim sources and corpus
are instrumented; the linked OpenCV libraries are NOT instrumented.
No claim is made of sanitizing OpenCV's internal scratch implementation.
The exact-version runtime qualification is the native production-shim corpus;
the full Ada AUnit suite was run on 4.10, not claimed on 4.1/5.0.
GNATprove was not run: no SPARK unit was changed, and foreign/native numerical
behavior here is established by testing, not formal proof. GNATcov was not run.

Validation-boundary review: retained duplicates are source 2-D/type/channel and
positive geometry (adapter/native indexed storage), effective area (native
signed multiplication/UInt8 accumulator overflow), representability/byte-stride
checks (native signed pointer arithmetic and adapter offsets), and object
identity (publication must not rebind source). Each has an ABI-safety reason
documented in the shim/planner. No diagnostic-only duplicate validation remains.

## Provenance

Task 046 starts at `499e963333c446f1e87e29b93314ced126ec0599`.
Fresh upstream checkouts, not Task 043/045 worktrees, were fetched and checked
out at these exact tags:

| Tag | Commit |
| --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

Authoritative paths inspected in each checkout:

- `modules/imgproc/include/opencv2/imgproc.hpp`
- `modules/imgproc/src/box_filter.dispatch.cpp`
- `modules/imgproc/src/box_filter.simd.hpp`
- `modules/imgproc/src/filter.dispatch.cpp`
- `modules/imgproc/src/filter.simd.hpp`
- `modules/imgproc/src/filterengine.hpp`
- relevant allocation, ROI, and step code in `modules/core/src/matrix.cpp`

URLs use `https://github.com/opencv/opencv/blob/<tag>/<path>`.
This document records research, not completed feature qualification.

## Declaration and selected types

The declaration in all three tags is:

```cpp
void sqrBoxFilter(InputArray src, OutputArray dst, int ddepth,
                  Size ksize, Point anchor = Point(-1, -1),
                  bool normalize = true, int borderType = BORDER_DEFAULT);
```

The implementation, rather than the historical parameter prose, establishes
output depth semantics. With explicitly requested `CV_64F`, UInt8 selects
`SqrRowSum<uchar, int>` and `ColumnSum<int, double>`; Float32 selects
`SqrRowSum<float, double>` and `ColumnSum<double, double>`. Channel counts
are preserved by `CV_MAKETYPE`. Other native combinations exist but are not
part of the requested public API.

The selected row filter has no SIMD specialization. Neither selected column
filter has a specialization: both use the generic scalar template, even in
CPU-dispatched translation units. SIMD specializations for other destinations
are not evidence for the safety or rounding of these selected filters.

## Effective kernel and scaling

Before constructing filters, all tags reduce height to one for a single-row
image, and width to one for a single-column image, exactly when normalization
is enabled and `borderType != BORDER_CONSTANT`. This is independent of the
whole-parent size. Neither unnormalized mode nor constant border shrinks.
Negative anchor components subsequently become effective dimension / 2;
this includes the asymmetric centered convention for even kernels.

Scaling is `normalize ? 1./(ksize.width*ksize.height) : 1`. The multiplication
is signed int, before conversion to double. A widened preflight must bound
the *effective* product by `INT_MAX`, including for Float32.

## UInt8 accumulator proof

Let A = effective width times effective height. Require A <= 33025,
because floor(INT_MAX / 65025) = 33025. Each square is in [0,65025].

- Initial horizontal partial sums are at most width * 65025 <= INT_MAX.
- The sliding difference of two squares lies in [-65025,65025].
- `s += new_square - old_square` evaluates that representable difference
  first. Its resulting value is the next nonnegative window sum, bounded
  by width * 65025. It does not evaluate `s + new_square` separately.
- Column initialization sums height - 1 horizontal rows. Adding `Sp` gives
  at most A * 65025. Subtracting `Sm` leaves a nonnegative sum of height - 1
  rows. All partial sums, full sums, and subtraction results fit signed int.
- Scaling converts the representable sum to double and multiplies by a
  positive reciprocal. No signed wrapping or saturation is used as proof.

At A=33025 the maximum sum is 2147450625. At A=33026 it is 2147515650,
which exceeds INT_MAX. Channels accumulate independently, but index products
still expand by the channel count and require separate bounds.

## Float32 arithmetic

A finite binary32 magnitude is less than 2^128. Conversion to binary64 is
exact, and its square is less than 2^256, far below binary64 overflow.
For A <= INT_MAX, an ideal positive accumulation is less than 2^287.
This alone is not a complete proof for arbitrarily many rounded sliding
updates: a final implementation must bound the executed update counts and
rounding error as well as the ideal window sum. Native incremental arithmetic
can propagate NaN/infinity beyond their ideal local windows; no sanitization
or mathematical-local-sum guarantee should be claimed for nonfinite samples.

## FilterEngine expressions requiring preflight

The following are signed expressions in the selected historical engine:

- `borderLength * borderElemSize`, `srcElemSize * borderLength`, and
  `borderLength * channels` in `init`.
- `height + 3`, `max(anchor, height-anchor-1)*2+1` for buffer row counts.
- `source_width + kernel_width - 1`, its source-byte multiplication, and
  that sum plus `VEC_ALIGN` for the constant-border row.
- `bufElemSize * (int)alignSize(source_width, VEC_ALIGN)` for `bufStep`.
- `bi * bufStep` when obtaining a ring-buffer row pointer. The allocation
  itself multiplies by vector `size()` and is size_t; that does not make
  the subsequent signed row-pointer product safe.
- ROI coordinate additions in `dx2`, `endY`, and vertical border lookup.
- `(width-1)*channels`, `kernel_width*channels`, and
  `i + kernel_width*channels` in `SqrRowSum`.
- `roi.width*channels`, byte offsets, and border-table indices in `proceed`.
- `dststep*i` when advancing the destination between column-filter batches.
- source/destination steps narrowed to int in `apply`.

Bounds must be evaluated with widened arithmetic. Native allocation failure
must remain an exception-translated failure, not become an arbitrary public
allocation-size ceiling. Relevant size_t extents must also fit ptrdiff_t for
pointer differences and address formation.

## Logical image isolation, aliasing, and tiny-image pointers

`sqrBoxFilter` unconditionally calls `src.locateROI(wsz, ofs)` in every tag.
Consequently a Region cannot be passed directly if surrounding parent pixels
must be excluded. Merely adding BORDER_ISOLATED is not established as a fix:
this entry point still resolves the parent and passes it into FilterEngine.

In `FilterEngine__proceed`, nonconstant horizontal Float32 borders select:

```cpp
const int* isrc = (const int*)src;
int* irow = (int*)row;
irow[i] = isrc[btab[i]];
```

Bytewise snapshot construction alone does not remove that later typed access.
An allocation-backed bytewise padded snapshot is a candidate adaptation:
provide its own logical-border margins, pass an ROI with the original logical
dimensions, and arrange sufficient margins that native `dx1` and `dx2` are
zero. Native arithmetic still uses the same effective kernel and the same
logical output dimensions. This needs an explicit construction proof and
runtime interception tests before production use.

Pointer formation must be reviewed separately from dereference: the source
loop advances `src += srcstep` even after its last consumed row. On a normal
tightly backed full logical image with zero x-offset this reaches one-past;
on a subimage it may not. A private storage adaptation must ensure the final
advanced pointer remains within or one-past its actual allocation. The column
loop similarly advances destination to the end; batch multiplication must
remain signed-representable. Tiny images are not excluded by these findings.

Core `locateROI` uses pointer differences and narrows computed parent sizes
to int. Private parent dimensions and extents must be representable; external
source strides should be read only through logical byte rows and must not be
forwarded to the engine without a proven narrowing bound.

## Dispatch and version differences

All tags have an OpenCL route conditional on `_dst.isUMat()`. A local owning
`cv::Mat` output does not satisfy it. There is no sqrBoxFilter HAL, IPP, or
OpenVX invocation in these entry points; those calls in boxFilter are not
reachable simply because both operations share this source file.

4.10 adds an explicit nonempty assertion and uses ptrdiff_t in
`src.ptr() + y * (ptrdiff_t)src.step`. 4.1 uses a size_t step in that
expression; a reviewed adapter must avoid negative y in that version.

5.0 introduces stateless tiled filtering and marks SqrRowSum stateless.
However, the selected generic ColumnSum remains stateful and inherits
`isStateless() == false`. FilterEngine requires both row and column filters
to be stateless, so this operation does not enter the tiled path. No global
thread-count modification is necessary to avoid it.

## Qualification status

The untouched production baseline built successfully and executed all 1070
registered tests: 1070 passed, zero failed assertions, zero unexpected errors.
Installed OpenCV reports 4.10.0.

No new binding, arithmetic helper, snapshot adapter, numerical oracle, native
harness, or exact-version runtime qualification is implemented yet. The
safety review is incomplete; this is not `SAFETY_GATE_NOT_ESTABLISHED` and
does not conclude that the requested semantics are impossible to provide.

## Continuation: interior-centered ROI and the 4.1 apply expression

For the proposed centered interior ROI, choose offsets ax=kw/2 and ay=kh/2,
and sufficient trailing halos. Substituting these offsets into start gives
dx1=dx2=0. Native BORDER_REPLICATE avoids both constant-row initialization
and the incompatible horizontal `int*` border branch. This alone is not a
complete pointer proof.

In 4.1 `FilterEngine__apply` line 306 evaluates
`src.ptr() + y*src.step`. A nonzero top halo gives
`startY=0`, `ofs.y=ay`, and `y=-ay`. The size_t step converts the negative
operand to unsigned before multiplication. For example, a 3x3 kernel with
ay=1 and parent step=20 evaluates the offset as SIZE_MAX-19. Backing memory
before the ROI does not establish validity for that unsigned pointer addition
in portable C++. 4.10 and 5.0 explicitly cast the step to ptrdiff_t.
Therefore the centered interior-ROI candidate is not established across all
three versions. Merely adding more prefix storage does not change this
expression. This is a reason to evaluate an equivalent native fallback, not
a conclusion that the requested public operation is impossible.

## Equivalent native fallback: coordinate shift and top-left anchor

An alternative avoids negative y without changing global OpenCV settings:

1. Compute kw/kh from the ORIGINAL dimensions, mode, and border.
2. Define ax=kw/2 and ay=kh/2 (the original centered anchor).
3. For normalized input, widen a native singleton axis to two only if its
   effective kernel dimension exceeds one. Otherwise preserve that axis.
4. Allocate parent width=native_width+kw-1 and
   parent height=native_height+kh. The last row is a pointer guard.
5. Fill parent pixel (p,q) with the ORIGINAL border extension at
   logical coordinate (p-ax,q-ay), copying exact representations bytewise.
6. Pass its top-left native_width x native_height ROI to sqrBoxFilter,
   effective kernel (kw,kh), explicit anchor (0,0), and BORDER_REPLICATE.
7. Retain output rectangle (0,0,original_width,original_height) in separate
   owning Float64 storage, with final-only publication.

For any retained output coordinate (x,y), native selects parent samples
(x+i,y+j), 0<=i<kw and 0<=j<kh. By construction these are exactly the original
logical-border samples at (x+i-ax,y+j-ay). Every original centered window,
including even kernels, therefore has the same sample sequence. The scale
uses the original effective kw*kh. Channels are unchanged.

Normalized Constant-border singleton axes with effective dimension >1 are
widened, preventing the replicate selector from incorrectly reducing them.
Added logical pixels, as well as halos, are zero outside the ORIGINAL logical
image. Other singleton normalized borders already have effective dimension
one, so any further native reduction is an identity. Unnormalized mode has
no native reduction. This covers 1x1, 1xN, and Nx1 independently on each axis.
The fallback intentionally uses (0,0), not the initially requested native
sentinel. Its public centered semantics come from the coordinate shift.

Under these dimensions and anchor, `ofs=(0,0)`, `startY=0`, and native y=0
in all three versions. `dx1=0` and
`dx2=max(kw-1+native_width-parent_width,0)=0`; `makeBorder` is false.
The replicate selector does not allocate or process a synthetic constant row.
Each required sample is physically present. The source copy is one contiguous
logical-expanded row from physical x=0. `endY=native_height+kh-1`, leaving a
full guard row. The final unconditional source increment therefore points
inside the parent's allocation, at the guard-row start. Destination increments
reach at most one-past its own full native output allocation.

The selected column sums remain stateful in 5.0, so this construction still
uses the reviewed non-tiled engine. This is a source-level equivalence and
address argument; no runtime interception or full safety qualification has
yet verified an implementation of it.

## Research-stage arithmetic plan

`cpp/squared_box_layout_fits.hpp` now contains an allocation-free candidate
plan. It is NOT called by the production shim. It uses int64_t for:

- original effective area and channel-expanded row indexing;
- widened native ROI and parent dimensions;
- `kh+3` and `2*(kh-1)+1` (the (0,0)-anchor buffer-row expression);
- expanded source byte width and border-table length;
- 64-column aligned buffer width (all pinned private.hpp files define
  CV_MALLOC_ALIGN=64), buffer step, and last signed ring-row offset;
- output byte width and maximum destination batch advancement;
- allocation and pointer-difference extents.

Ordered checks bound each factor before later wider products are evaluated.
All accepted factors in final extent products are at most INT_MAX, so their
product is representable in int64_t. Buffer-row count bounds also protect the
`rowCount` increment and signed expression intermediates. This plan still
needs a complete bounds audit and source external-stride validation before
production integration. It does not purport to validate arbitrary malformed
Mat headers or externally invalid backing allocations.

The border-index helper uses periodic reduction in int64_t: Reflect has
period 2*n and Reflect_101 has period 2*(n-1), with a separate singleton case.
It performs no negation of a possibly minimal signed coordinate. Research
tests compare it against independent repeated folding for lengths 1..9 and
coordinates -100..100, and cover accumulator limits and exact geometry/index
boundary transitions without allocating images.

## Remaining typed-buffer/object-lifetime proof gate

Bypassing horizontal `int*` border copying does NOT by itself establish the
remaining native Float32 accesses. FilterEngine declares both `srcRow` and
`ringBuf` as `std::vector<uchar>` in all three tags. It copies source bytes into
srcRow, then SqrRowSum reads it through `const float*`; the row filter writes
ringBuf through `double*` (or `int*` for UInt8). ColumnSum reads these typed
buffer values and writes owning Mat output through `double*`. Its own
`std::vector<ST> sum` has the expected element type.

The pending proof must distinguish aligned storage from actual permitted
typed object access and lifetime. vector<uchar> storage plus alignment alone
is not an object-lifetime proof for C++17. A scalar/SIMD test or sanitizer pass
would not supply that language-level proof. It remains to establish the
applicable OpenCV/compiler storage model, or evaluate an equivalent native
route that avoids any unresolved access. No new production binding is enabled
while this gate remains open. No claim is made that every possible safe
fallback has been exhausted.

Float32 finite sliding accumulation also still needs the executed-operation
rounding bound, not just the earlier ideal-window magnitude bound. Native
finite numerical-oracle, nonfinite, Region, and exact-version runtime tests
remain outstanding.

## Continuation results and finite arithmetic bound

The preceding outstanding-work statements describe the state before this
continuation. The research probe `docs/probes/squared_box_adapter.cpp` now
executes the coordinate-shift/top-left-anchor construction on installed
OpenCV 4.10.0. It checks actual locateROI geometry and compares retained
outputs with an independent iterative-border, long-double window oracle.
Both GCC 14.2 and Clang 19 strict C++17 builds with ASan/UBSan passed all
2880 cases each: UInt8/Float32 C1/C3, both modes, four borders, five kernels
(1x1, 3x3, 2x4, 3x5, 9x8), singleton and ordinary dimensions, and owning
sources versus noncontinuous Regions. This is NOT a production-shim harness.
The probe and arithmetic helper are instrumented; installed OpenCV shared
libraries are NOT instrumented. Passing these runs does not close the typed
scratch-storage lifetime gate.

The allocation-free layout/border tests also passed under both compilers
with `-Wall -Wextra -Wpedantic -Werror` and ASan/UBSan. Added inclusive/next
rejected boundaries exercise channel-expanded aligned ring offsets and
destination batch byte products without image allocation.

For finite samples, a conservative bound need not assume incremental sums
remain nonnegative after rounding. Let M=2^256 bound a squared binary32
sample. With kw,native_width <= INT_MAX, an absolute-value recurrence for a
row accumulator includes at most kw initial squares and native_width updates,
each with difference magnitude at most M (or conservatively 2*M after
rounding). There are fewer than 2^34 rounded operations per accumulator.
For binary64 unit roundoff u=2^-53, the growth factor (1+u)^(2^34) is less
than 2. Thus a conservative row magnitude bound is 2^292, allowing generous
slack beyond (kw+2*native_width)*M. Subnormal absolute errors are negligible
against this bound and can be included in that slack.

Column accumulators start with kh-1 rows and perform at most native_height
add/subtract updates, with fewer than 2^34 rounded operations. Taking absolute
values rather than relying on cancellation gives a bound below 2^328, again
including a factor of two rounding growth and slack. Binary64 overflow begins
near 2^1024, so all these finite intermediates are representable. Scaling is
a positive reciprocal <=1 after the signed effective-area preflight. This
argument establishes absence of finite arithmetic overflow, NOT exact local
sum accuracy, nor ideal locality for NaN/infinity.

## Current unresolved gate and work remaining

The principal source-level gate remains the C++17 typed scratch-storage
object-lifetime/access model described above. The top-left fallback avoids
the 4.1 unsigned negative-offset expression, the horizontal incompatible
border copy, and synthetic constant rows. It does not change native
vector<uchar> scratch buffers. Establishing the applicable implicit-lifetime
rules/compiler guarantees (including whether they apply as defect-resolution
extensions to the pinned library builds), or finding an equivalent native
route, is still required before asserting complete portable safety.

No production export or Ada API has been added. AUnit additions, real-shim
interception, malformed ABI inputs, external strides, publication/ownership,
nonfinite behavior, 4.1/5.0 runtime qualification, CI wiring, and public
documentation remain incomplete. No feature commit, push, or PR exists.
The helper is a research candidate, not an approved final production plan.

## Final bounded feasibility gate — disposition

**SAFETY_GATE_NOT_ESTABLISHED** (Outcome 3).

This supersedes the earlier in-progress status. No production binding is
authorized, no feature PR is opened, and no claim is made that OpenCV is
unusable in practical compiler environments. The requested portable ISO
C++17 proof and full-domain equivalent fallback were not established under
the task's fixed boundaries.

### Gate A: published C++17 versus later implicit creation

Primary references actually inspected:

- https://www.ece.uvic.ca/~frodo/cppdraft/n4659/html/intro.object
- https://www.ece.uvic.ca/~frodo/cppdraft/n4659/html/basic.life
- https://www.ece.uvic.ca/~frodo/cppdraft/n4659/html/basic.lval
- https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2020/p0593r6.html
- https://clang.llvm.org/cxx_status.html
- https://gcc.gnu.org/projects/cxx-status.html

N4659 intro.object paragraph 1 lists creation by definition, new-expression,
union active-member change, or temporary creation. Paragraph 3 permits an
unsigned-char array to PROVIDE storage for an object that is created there;
its example explicitly uses placement new. It does not create arbitrary
numeric objects merely because the array is large and aligned enough.
basic.life paragraph 1 specifies when the lifetime of an object begins; it
does not independently supply the missing object-creation operation.
basic.lval paragraph 8 permits character access to other representations,
not the reverse permission to read live uchar elements as arbitrary floats.

Exact scratch trace (paths relative to each pinned upstream checkout):

| Item | 4.1.0 | 4.10.0 | 5.0.0 |
| --- | --- | --- | --- |
| vector<uchar> ringBuf/srcRow | filterengine.hpp:264-265 | :268-269 | :277-278 |
| srcRow resize | filter.simd.hpp:114 | :116 | :117 |
| ringBuf resize | filter.simd.hpp:137 | :139 | :140 |
| row byte copy | filter.simd.hpp:240 | :242 | :243 |
| SqrRowSum casts | box_filter.simd.hpp:1295-1296 | :1295-1296 | :1709-1710 |

The vectors allocate and construct uchar elements. The row memcpy fills
srcRow's byte elements. SqrRowSum converts that address to `const T*`, with
T=float for Float32, and accesses `S[i]`. It converts an aligned ring-row
address to `ST*` and executes `D[0]=s` and `D[i+cn]=s`, with ST=int for UInt8
or double for Float32. Generic ColumnSum reads these addresses as
`const ST* Sp` / `Sm`. Its own `vector<ST> sum` is correctly typed; this does
not construct numeric objects in the separate ring buffer.

No intervening placement new, typed allocator construction, union lifetime
switch, or other N4659 creation operation was found in this selected path.
Ring rows are aligned to CV_MALLOC_ALIGN=64. srcRow is ordinary byte-vector
storage without a separately expressed numeric alignment guarantee.
Alignment does not resolve object creation in either buffer.

Concrete minimal execution: UInt8 C1 1x1 image, 1x1 kernel, unnormalized,
with value 7. SqrRowSum writes integer 49 through `int* D` into the uchar
ring vector and ColumnSum reads it through `const int*`. Even this case
requires the missing typed object creation under the published model.
Float32 value 1 similarly requires a float read from srcRow and double
write/read in ringBuf. More halos, singleton widening, alternate anchors,
direct-safe geometry, and arithmetic preflights cannot construct objects
inside privately allocated native scratch vectors. A caller cannot placement-
construct them before allocation without intercepting/changing OpenCV.

P0593R6 explicitly proposes implicit creation in allocation, byte-array
lifetime-starting operations, and memcpy/memmove. It discusses DR-level
language fixes separately from library additions. This is relevant later
wording, not wording present in N4659. Compiler defect-resolution behavior
may supply broader guarantees in older language modes, but compiler status
pages and successful experiments do not establish those guarantees for every
already-built pinned OpenCV dependency. No specific extension was adopted
as a project requirement, and no supported-library build provenance proving
such guarantees was established. Compiling only this shim as C++20 would
not change the compiled native scratch accesses. `-fno-strict-aliasing`
does not create objects and is not a substitute proof.

### Gate B: native squared integral source findings

Inspected 4.1 `sumpixels.cpp`, including integral_, Integral_SIMD, HAL/IPP
entry points, plus `sumpixels.avx512_skx.cpp`; inspected 4.10 and 5.0
`sumpixels.dispatch.cpp`, `sumpixels.simd.hpp`, and AVX512 dispatch references.
4.10 and 5.0 dispatch/scalar code is identical through the public C++ API;
5.0 removes the legacy C wrapper after that code.

For sum depth CV_64F and square depth CV_64F, all tags support
`integral_<uchar,double,double>` and `integral_<float,double,double>` with
channels independently interleaved. The branch tilted==nullptr and
sqsum!=nullptr performs `sq += (QT)it*it` and adds the above-row prefix;
it does NOT allocate the tilted AutoBuffer. Float32's generic SIMD template
declines, reaching scalar code after HAL/IPP decline. UInt8 double/double
can reach AVX512 for C1/C3; ordinary SIMD otherwise declines squared sums.
IPP's squared-sum branches do not accept sum depth CV_64F. HAL precedes both
and is a build-specific replacement requiring separate qualification.
Mat outputs exclude the UMat-only OpenCL path. No IPP/HAL/AVX512 backend
execution is claimed by the probe results.

Removing FilterEngine does not remove ALL lifetime assumptions. Public
integral creates output Mats; StdMatAllocator obtains raw `fastMalloc`
storage (4.1/4.10 matrix.cpp:147; 5.0:574), not double array new or placement
construction. fastMalloc uses malloc/posix_memalign/platform allocation.
The scalar integral then writes through double pointers. The same published
C++17 creation issue therefore remains for newly allocated native outputs.
Typed caller-owned arrays with external output headers could address this
specific lifetime issue; that is not proof that default owning outputs do.

Other required guards/adaptations include:

- input width+1 and height+1 in output geometry;
- width*channels and width+channels signed intermediates;
- narrowed source/sum/square steps in ELEMENT units, sumstep+channels;
- signed AVX512 row products (e.g. y*sqsumstep) and byte-step IPP casts
  where those alternatives are reachable;
- allocation extents and source snapshot guard geometry.

There is also a scalar final-pointer defect: in 4.1 lines 288-291 and
4.10/5.0 lines 237-240, the output cursor initially points at row 1,
column cn. Each row advances a full sumstep through the inner/outer updates.
After height rows it points at (height+1)*sumstep+cn, beyond a tight
(height+1)-row allocation. For a 1x1 C1 double integral, step=2 doubles,
the final cursor is at element 5 of a 4-element allocation. This is pointer
formation even without dereference. Caller-owned guarded output storage
could contain it; sanitizer silence in an uninstrumented library cannot
prove otherwise. Input adaptation alone does not repair the output extent.

Finite squared prefixes are nonnegative and, with widened dimension bounds,
remain far below binary64 overflow: a finite binary32 square <2^256 times
fewer than 2^62 signed-dimension pixels is <2^318, with rounding slack still
far below 2^1024. The simultaneously computed ordinary sum should also be
Float64, avoiding default UInt8 Int32 overflow. This magnitude argument
does NOT prevent loss of local differences from rounded prefixes.

### Gate C: new comparison evidence, not a repeated adapter campaign

Added `docs/probes/squared_box_integral_gate.cpp`. It reuses the preserved
adapter utilities without invoking the 2880-case campaign. Only explicit
`return 0` was added to that campaign's main so it can be renamed and included
without a non-main missing-return warning.

The new probe compares shifted native sqrBoxFilter, native integral with
Float64 sum/squared outputs, and independent iterative-border long-double
window summation. Four-corner operands are converted to long double BEFORE
subtraction. On installed OpenCV 4.10.0:

- 512 ordinary cases passed both comparisons (UInt8/Float32 C1/C3, both
  modes, four borders, singleton axes, odd/even/oversized kernels, negative
  finite Float32 values, and noncontinuous Regions).
- Nine adversarial cases produced 24 integral/oracle and 21 box/oracle
  mismatches at individual output samples. These are expected observations
  recorded by the probe, not assertion failures.
- Both GCC 14.2 and Clang 19 strict C++17 ASan/UBSan builds passed the probe's
  assertions and produced the same counts. Only probe code was instrumented;
  installed OpenCV was NOT instrumented. This is not real-shim qualification.

Decisive finite counterexample: a 2x3 Float32 image with top row all 2^40,
bottom row all 1, 3x1 Sum_Of_Squares and Constant border. Bottom-row oracle
and shifted native box values are [2,3,2]; integral values are [0,0,0].
Prefixes already lost the unit squares alongside 2^80 contributions.
Long-double subtraction cannot recover information absent from double
corners. This is not a tolerance-level difference.

Another finite observation is important: for row [2^40,1,-2], 1x1 kernel,
native box gives [2^80,0,3], integral gives [2^80,0,0], and oracle gives
[2^80,1,4]. Using max finite Float32 instead of 2^40 has the same small-value
outputs. Thus even native incremental arithmetic does not guarantee a tight
mathematical oracle tolerance for every finite high-dynamic-range input.
The original finite-oracle wording must not be strengthened into an accuracy
claim contradicted by this evidence; the integral route also fails native
equivalence directly.

NaN/+Inf/-Inf were tested horizontally and vertically. Their influence
persists after their ideal local window has passed; Inf-Inf produces NaN.
Neither integral corner arithmetic nor incremental box arithmetic is an
ideal nonfinite local sum. Example with an infinite upper row and normalized
3x1 constant border: native bottom row is NaN while an independently reset
per-window calculation would return finite [2/3,1,2/3]. No samples were
sanitized or rejected. The probe intentionally reports classifications,
not exact NaN payload or sign guarantees.

### Alternative feasibility and final decision

Direct sqrBoxFilter, narrowed arithmetic, centered private padding, and the
shifted private layout were evaluated in order. The shifted layout resolves
the earlier geometry and border problems but cannot repair native scratch
object creation. A pre-squared boxFilter is both disallowed by the task and
still uses FilterEngine; switching native pixel depth does not create ring
objects. Changing library compilation, patching/vendoring, or requiring a
GPU is outside the authorized boundaries.

Global squared integral is not an equivalent fallback: finite prefix loss
has the explicit counterexample above, and newly allocated native output
storage still lacks the required published-C++17 creation proof. Guarded
typed external outputs could repair storage/pointer concerns but cannot
restore rounded-out numerical information.

Bounded spatial tiling does not give a full-domain guarantee: arbitrarily
large binary32 dynamic range can put the same large and small samples in
one tile. Smaller tiles move the problematic boundary rather than bound
relative error. Per-window integral calls remove unrelated prefix history,
but reset native incremental history and hence change both finite rounding
and observed nonfinite propagation; they are not an equivalent native
sqrBoxFilter implementation. Adaptive exact accumulation/correction or
reconstruction of native accumulator history would amount to a replacement
filtering algorithm, not the approved native fallback. No such production
algorithm was added.

Neither complete portable original path nor full-domain equivalent native
fallback is established. Stop Task 046 research here rather than repeat
sanitizers or add speculative adapters. Recommend choosing a different
Imgproc feature; changing the language/build or numerical contract would
require a separate explicit authorization.

### Final repository/validation state

Branch `feature/squared-box-filter`, worktree `/tmp/imgproc046-squared-box`,
HEAD `499e963333c446f1e87e29b93314ced126ec0599`. All research remains untracked.
No production export/Ada API, feature commit, push, or PR exists. The last
full AUnit evidence is the preserved untouched baseline 1070/1070 PASS;
it was not rerun for research-only additions. Exact 4.1/5.0 runtime probes
were not run: rejection follows pinned source analysis plus a concrete
4.10 runtime counterexample, not claimed successful exact-version
qualification. No hosted CI or production sanitizer coverage is claimed.