# Portable Bayer demosaicing: exact-tag source review

## Evidence and limits

Reviewed **4.1.0**, **4.10.0**, **5.0.0**, independently, not moving branches:

- <https://github.com/opencv/opencv/tree/4.1.0>
- <https://github.com/opencv/opencv/tree/4.10.0>
- <https://github.com/opencv/opencv/tree/5.0.0>

For each root, inspected `modules/imgproc/include/opencv2/imgproc.hpp`,
`modules/imgproc/src/color.cpp`, `color.hpp`, and the **complete**
`demosaicing.cpp`. Also inspected Core `matrix.cpp`, `alloc.cpp`, `copy.cpp`,
and `include/opencv2/core/hal/intrin.hpp` (the intrinsic architecture dispatcher).
The UInt8 SIMD implementations are defined directly in `demosaicing.cpp`;
UInt16 uses `SIMDBayerStubInterpolator_<ushort>` and scalar invokers.

Local runtime verification is **OpenCV 4.10.0 only**. No local 4.1.0/5.0.0,
ARM SIMD, IPP, or OpenCL runtime verification is claimed.

## Mapping and native surface

The declaration in every tag is:

```cpp
void demosaicing(InputArray src, OutputArray dst, int code, int dstCn = 0);
```

One private C++ mapping chooses historical aliases; no native integer code
crosses from Ada. Private physical selectors are RGGB=0, GRBG=1, BGGR=2,
GBRG=3; methods bilinear=0, VNG=1, EA=2; orders BGR=0, RGB=1.

| Physical tile at logical (0,0) | BGR short prefix | RGB alias refers to BGR prefix |
|---|---|---|
| RG / GB (`RGGB`) | `COLOR_BayerBG2BGR` | `COLOR_BayerRG2BGR` |
| GR / BG (`GRBG`) | `COLOR_BayerGB2BGR` | `COLOR_BayerGR2BGR` |
| BG / GR (`BGGR`) | `COLOR_BayerRG2BGR` | `COLOR_BayerBG2BGR` |
| GB / RG (`GBRG`) | `COLOR_BayerGR2BGR` | `COLOR_BayerGB2BGR` |

The same permutation applies to `_VNG`, `_EA`, and BGRA/RGBA. Gray uses
BG/GB/RG/GR in physical order, without color-order selection. Base BGR codes
are 46..49; VNG 62..65; Gray 86..89; EA 135..138; alpha 139..142.

**4.1.0 does not have long physical aliases or the later explanatory enum
comments** (`imgproc.hpp:737..783`). Its invokers independently establish the
mapping: `blue=-1` for BG/GB writes the top-left CFA color to red, and
`start_with_green` distinguishes GB/GR. VNG's `blueIdx` and EA's `blue`
establish the same order. 4.10.0 (`749..848`) and 5.0.0 (`741..832`) explicitly
declare `COLOR_BayerRGGB2BGR = COLOR_BayerBG2BGR`, and the other physical aliases.
RGB long aliases exchange RGGB/BGGR and GRBG/GBRG BGR codes, as in the table.
Thus only the **short aliases** are shared by all three exact headers.

The direct entry validates unsigned depth and C1, creates same-size/depth
output, then dispatches Gray, bilinear/alpha, VNG, or EA. Native `dcn` flexibility
is deliberately not exposed: Gray C1, color C3, alpha C4, EA C3. VNG's entry
checks UInt8 after destination creation; the shim rejects it before allocation.

| Public operation/method | UInt8 | UInt16 | Channels |
|---|---|---|---|
| Bilinear color | yes | yes | 3 |
| VNG color | yes | no | 3 |
| Edge-aware color | yes | yes | 3 |
| Direct bilinear Gray | yes | yes | 1 |
| Bilinear alpha | yes | yes | 4 |

All other Core depths reject; there is no depth conversion. `Alpha<T>::value`
returns `numeric_limits<T>::max()` (4.1:695, 4.10:740, 5.0:812), and both
scalar stores and UInt8 alpha SIMD use this maximum. Native border copying
propagates alpha for ordinary nondegenerate images: 255/65535.

Gray uses R2Y=4899, G2Y=9617, B2Y=1868, SHIFT=14 in every tag. For constant
components its scalar value is `(4899*R+9617*G+1868*B+8192)>>14`; interpolation
uses SHIFT+1/+2 with doubled/quadrupled coefficients. NEON's saturating
multiply-high rounding can differ from the scalar formula; assertions permit
one UInt8 luminance level (UInt16 remains scalar and exact).

### Legacy UInt16 Gray signed-overflow safety

Additional exact-tag inspection confirms `const int G2Y = 9617` in **4.0.0,
4.1.0, 4.2.0, 4.3.0, 4.4.0, 4.5.0, 4.5.1, 4.5.2, 4.5.3, and 4.5.4**.
**4.5.5** changes it to `const unsigned G2Y = 9617`; **4.6.0, 4.7.0, 4.8.0,
4.9.0, 4.10.0, and 5.0.0** retain the fix. The exact transition is independently
supported by upstream commit
[`542b3e8a64a1516657ec84fd9b2acaaa2baf6440`](https://github.com/opencv/opencv/commit/542b3e8a64a1516657ec84fd9b2acaaa2baf6440)
(2021-12-13), whose sole code change makes G2Y unsigned. Compare the exact
[`4.5.4`](https://github.com/opencv/opencv/blob/4.5.4/modules/imgproc/src/demosaicing.cpp#L606)
and [`4.5.5`](https://github.com/opencv/opencv/blob/4.5.5/modules/imgproc/src/demosaicing.cpp#L606)
sources. Despite the historical commit's description, signed overflow is
**undefined behavior**, not a harmless version-specific luminance result.

The vulnerable expression occurs in both the main pair loop and final tail:

```cpp
t1 = (bayer[1] + bayer[bayer_step] + bayer[bayer_step+2]
      + bayer[bayer_step*2+1]) * G2Y;
```

These are the four axial green neighbors of a red/blue center. UInt16 samples
promote to signed int; their sum is at most 262140 and is safe, but multiplying
by signed G2Y can overflow **before** assignment to unsigned t1. The exact
32-bit signed limit is `INT_MAX / 9617 = 223300`:

- `223300 * 9617 = 2147476100 <= INT_MAX` (safe);
- `223301 * 9617 = 2147485717 > INT_MAX` (first unsafe sum).

Other individual Gray terms remain below INT_MAX at full UInt16 range. The
binding version-gates only the UInt16 direct-Gray scan with:

```cpp
CV_VERSION_MAJOR == 4 &&
    (CV_VERSION_MINOR < 5 ||
     (CV_VERSION_MINOR == 5 && CV_VERSION_REVISION < 5))
```

After raw layout/span/allocation preflight and construction of the **packed
independent snapshot**, the helper sums those neighbors in uint64_t and rejects
any sum above 223300 before `cv::demosaicing`. It scans the snapshot, **not
parent-backed Source storage**. Rejection returns the existing private
invalid-argument status with a legacy-luminance diagnostic; the public operation
raises `OpenCV.OpenCV_Error`. Source and the existing raw Destination remain
unchanged; a subsequent valid call can succeed. No pixel cap of 55825 is used:
larger individual samples are accepted when executed neighborhoods are safe.
No values are rewritten, clamped, converted or emulated. **4.5.5+, 4.6+,
4.10 and 5.x have no such restriction**; all other Bayer operations are unchanged.

#### Exact native-loop coverage and physical parity

In 4.5.4 `Bayer2Gray_` sets `start_with_green` for short GB/GR Gray aliases,
which map to physical GRBG/GBRG. Native `size` excludes the outer one-pixel
border. For range row `i`, `bayer0` points to source `(i,0)` and destination
starts at `(i+1,1)`; each four-green expression surrounds `(y=i+1,x=bayer
column+1)`. Odd `range.start` toggles `start_with_green`, as does every completed
row, so parallel partitioning does not change physical phase.

If set, the optional first pixel is green and uses the two-neighbor terms,
then advances one column. The UInt16 `SIMDBayerStubInterpolator_<ushort>`
returns zero, skipping no centers. Each main iteration evaluates one non-green
center and the following green center, advancing two columns. The final tail,
when present, evaluates only the remaining non-green center. Border pixels are
copied and never evaluate the four-green expression.

Consequently the exact executed centers are `y=1..rows-2`, `x=1..cols-2`:

| Physical pattern selector | Non-green R/B center parity `(x+y) mod 2` |
|---|---|
| 0 RGGB, 2 BGGR | 0 (even) |
| 1 GRBG, 3 GBRG | 1 (odd) |

The helper examines precisely these sites, including first sites and tails for
odd/even widths and both row phases. All four axial neighbors there are green.
It contains no OpenCV numeric Bayer codes and is compiled even on fixed builds;
only its shim invocation is version-gated. Native raw dimensions below three
execute no four-green expression, so the helper imposes no additional minimum.

## VNG fallback and version differences

All three check `MIN(width,height)<8` and call `Bayer2RGB_`:
4.1:970..975, 4.10:1015..1019, 5.0:1080..1085. Requests 3..7 are accepted
publicly. **OpenCV falls back to bilinear demosaicing when either dimension is
below 8.**

Important native quirk: 4.1/4.10 `Bayer2RGB_` only recognizes bilinear/alpha
codes when setting `blue` and `start_with_green`; passing a VNG code falls
through to the BGGR/BGR phase regardless of requested alias. 5.0:1043..1048
adds the VNG codes to those tests. The wrapper deliberately does not rewrite
codes or emulate a corrected fallback. The 7x7 equality regression uses
physical BGGR/BGR, which is suitable across all three implementations.
Small VNG phase/order accuracy is consequently not a cross-version guarantee.

4.1:959..1508 and 4.10:1004..1531 use the input directly, advance `bayer` by
two rows, process `y=2 .. height-5`, fill horizontal borders, copy the first
two rows from row two, and copy the final four rows from row height-5.

5.0:1078..1594 first creates a **two-pixel BORDER_REFLECT_101** padded C1 Mat
with `copyMakeBorder`. It processes padded `y=2 .. padded_height-3`, writes
destination row `y-2`, and removes the manual 4.x border copies. This changes
border values (and can affect alignment-dependent interior texture values).
Tests assert installed-native invariants, not cross-version whole-image VNG
identity. No algorithm is emulated in Ada.

## Signed arithmetic preflight

The layout helpers in `cpp/bayer_layout_fits.hpp` are constexpr widened
arithmetic, called
**before snapshot copying or native allocation**. It uses division before potentially
large products and actual INT_MAX/ptrdiff_t limits, not arbitrary size caps.
Rows/cols originate as positive native int dimensions; intermediate products
and padding additions are uint64_t. All guards have concrete `ABI safety:`
comments.

### Bilinear and Gray

Independently found in all tags:

- casts `int(src.step/sizeof(T))`, `int(dst.step/sizeof(T))`;
- `range.start*bayer_step`, `range.start*dst_step` (Gray);
- `(range.start+1)*dst_step` (color);
- neighbors `bayer_step*2+2`;
- signed `width*dcn`, `delta*dcn`, and border
  `i+(height-1)*dst_step` (also native <=2-height handling).

Snapshot source element stride is **Columns**, even for UInt16; destination
element stride is **Columns*channels**. Require `Columns*channels<=INT_MAX`.
The maximal signed border index is `Rows*Columns*channels-1`, so the
least-restrictive whole signed-span condition is
`Rows*Columns*channels <= INT_MAX+1`, not unnecessarily `<=INT_MAX`.
The last index must fit; the one-past count need not be an int. With at least
three rows/columns, this also dominates the two-row neighbor expressions and
parallel starting products. Gray uses channels=1, color=3, alpha=4.

Raw 1x1 and 2x2 inputs retain safe native degenerate behavior and are tested.
One narrower safety exclusion is **Columns=1 with Rows>2** for bilinear/Gray
and VNG fallback: native pointer-bound formation `bayer+width-2` precedes the
`width<=0` branch. Color's degenerate stores address the preceding row and can
leave the current row uninitialized. EA's early <=2 return is safe, so does
not receive this exclusion. The **public >=3 policy is not copied to C++**.

### Edge aware

4.1:1525..1653, 4.10:1547..1676, 5.0:1610..1741 independently contain
`dcn<<1`, signed source/destination element-step casts, `dcn*delta`, neighbor
`sstep+1`, and signed `size.width *= dst.channels()`.
Public/native dcn is exactly 3, so shifts are 6 and width*3 must fit INT_MAX;
**no C4 bound is imposed on EA**. Initial row addressing multiplies by
`dst.step` (size_t); the final row pointer uses size_t `dstep`. There is no
signed whole-image row product to justify the bilinear total-int bound.
EA instead receives the byte-span ptrdiff_t bound needed for allocations and
addressable storage. Parallel scheduling uses `dst.total()/double`, not a
signed width*height scheduling product.

### VNG

All versions form `N2=N*2` through `N7=N*7`, `bufstep=N7*7`, then
`AutoBuffer<ushort>(bufstep*3)` => **N*147 in signed int**. Ring-row products
are at most two bufsteps, plane indices at most N*7, covered by that bound.
4.x N=Columns; 5.0 N=Columns+4. Portable preflight uses the latter whenever
VNG is actually reached (both dimensions >=8); fallback avoids VNG buffers.

Require Columns+4 and Rows+4 <= INT_MAX and `(Columns+4)*147<=INT_MAX`.
4.x signed `dststep*y`, final border copies, and 5.0 signed
`dststep*(y-2)` are covered by the C3 signed-span condition above.
For padded source, the largest `(y+dy)*bstep` term is
`(padded_height-2)*padded_width`. Require that product <=INT_MAX, rather than
the unnecessarily restrictive padded_height*padded_width signed bound.
`bstep*2+2` is dominated by N*147. Pointer addition of the remaining columns
is size-sized, protected by the full padded byte-span bound.
The C3 total bound already dominates the padded row term for dimensions >=8
(factor at most 1.25*1.5 < 3), but the explicit check records the native risk.

## Allocation and 32-bit portability

Allocations are packed C1 snapshot, C1/C3/C4 result, OpenCV-5 padded C1 UInt8,
and 147*N ushort scratch. Check each byte span against PTRDIFF_MAX; destination
span dominates snapshot. Padded bytes `(Rows+4)*(Columns+4)` and scratch
`N*147*sizeof(ushort)` have separate bounds. This also ensures size_t fit on
32-/64-bit targets and leaves ample size_t headroom for allocator alignment.
4.x `Mat::setSize` safely detects size_t overflow in auto steps (4.1 uses
int64, 4.10 uint64). 5.0 reworks setSize/StdMatAllocator with size_t products;
the binding does not rely on an equivalent checked rejection there. Existing
bounds make every Mat/scratch product safe before allocation. Out-of-memory
exceptions still translate normally and do not publish a partial result.

The optional fastMalloc fallback adds sizeof(void*)+CV_MALLOC_ALIGN without
a size overflow check. PTRDIFF_MAX is far below SIZE_MAX, leaving that small
headroom on both supported address widths. No extra arbitrary allocation cap
is needed. Helper static_assert tests simulate 32-bit address limits without
allocating giant Mats; they cover signed row/total boundaries, N*147, padding
addition rejections, buffer bytes, and EA's independent C3 bound.

## SIMD and backend reachability

4.1 uses SSE2 hardware-selected Gray/color/EA/VNG paths and a NEON branch
(notably alpha). 4.10 uses CV_SIMD128 universal intrinsics plus specialized
NEON Gray. 5.0 upgrades Gray to scalable CV_SIMD intrinsics; color/alpha/EA
and VNG retain CV_SIMD128 sections. UInt16 is scalar in all three.
Pixel arithmetic/rounding evolves (EA includes additional rounding constants
after 4.1); whole-image cross-version exact results are not promised.

Searched complete demosaicing files for CALL_HAL, IPP, OpenCL/UMat branches,
and vendor replacements: **none in the demosaicing dispatch or interpolation
loops**, for each tag. `color.cpp` has a separate cvtColor OpenCL dispatcher;
its Bayer cases simply forward to demosaicing. `color.hpp` color HAL helper
declarations do not constitute reachable Bayer interpolation hooks. The
binding does not reuse `color_may_use_ipp` or parent color-stride logic.

**Transitive qualification for OpenCV 5:** `copyMakeBorder` in Core
`copy.cpp:1225..1271` can try `CV_IPP_RUN_FAST(ipp_copyMakeBorder(...))` when
IPP IW is configured. Its low-level border helper receives pointer/size-sized
steps; it is not a color-conversion backend. Packed C1 byte strides are already
within INT_MAX by the local padded bounds. Its fallback table has only four
int entries and bounded byte width. The OpenCL border path requires a UMat
destination; here it is a local Mat and is unreachable. Thus it would be
incorrect to claim that **no IPP is transitively reachable** from 5.0 VNG.

## Snapshot, Region, ownership and validation boundary

The shim resolves borrowed Core source/destination, decodes selectors, checks
raw layout and arithmetic, deep-copies into a packed independent cv::Mat, demosaics
only that snapshot into a local result, then moves the result to Core output.
On affected builds, the UInt16 Gray safety scan follows snapshot construction
and precedes native demosaicing and result publication.
The Mat bridge retains ownership in Core. No source is modified or retained
as owned state. Same-handle/shared-storage raw calls are safe: snapshotting precedes
publication. All failures leave the old destination unchanged.

Snapshot copying deliberately allocates a packed Mat and copies each logical
row with size-sized memcpy, rather than using Mat::clone(). In all three tags
clone invokes copyTo, whose optional IPP `ippiCopy_8u_C1R_L` casts the original
parent byte step to int (copy.cpp 4.1:298, 4.10:364, 5.0:514). This row-copy
snapshot removes that backend/narrowing without imposing an INT_MAX parent
stride limit. Preflight checks `(Rows-1)*parent_step+row_bytes<=PTRDIFF_MAX`
using division before multiplication, and parent_step>=row_bytes. The source
handle/storage itself remains trusted Core-owned state, not an arbitrary
unvalidated cv::Mat supplied across the C ABI.

`copyMakeBorder` without BORDER_ISOLATED may expand an input ROI into parent
storage (5.0 copy.cpp:1238..1251). The snapshot is not a submatrix, eliminating
that context and arbitrary parent strides for every method. Source Pattern
refers to **logical coordinate (0,0)**, never an inferred parent phase. Odd
crops require caller-selected phase; no offsets are inspected or rewritten.

Retained duplicate layout guards: nonempty, dims=2, C1, UInt8/UInt16, and
UInt8-only VNG prevent incompatible neighborhood pointer/index interpretation.
Each is documented `ABI safety:`. Selector validation prevents table indexing
outside its arrays. The width-one tall exclusion protects native pointer
formation/uninitialized output, not the public minimum-size policy. There are
no duplicative semantic output postconditions.

## Verification

### Original feature verification

Baseline 687; **43 focused new AUnit tests**: final **730 registered, 730
executed, 730 passed**, zero failed assertions and zero unexpected errors.
The physical fixture uses explicit 2x2 R/G/B tiles, independent of native codes.
Coverage includes all patterns/orders, both unsigned depths, fixed luminance,
alpha maximum (including borders), actual textured EA/VNG, 7x7 fallback,
Region/clone equality and outside-parent mutation, fresh independence, public
rejection, malformed raw selectors/layout/null handles, atomic sentinels,
recovery and native-safe degenerate raw sizes. Arithmetic helper tests are
allocation-free. Strict Ada includes -gnatwc; C++ is warnings-as-errors.
GNATprove/coverage were not run for this non-SPARK foreign-algorithm slice.

### Corrective regression coverage

The corrective keeps **730 AUnit tests**, using a standalone native regression
rather than adding a public/test version API. `tests/bayer_layout_test.cpp`
checks exact sums 223300/223301, full-range rejection, and every interior site
of fixed arrays with dimensions 3..9 against independent physical CFA tiles.
Unsafe crosses on actual R/B centers reject; equally bright crosses on green
centers do not. It allocates no image storage dynamically.

`tests/run_bayer_gray_test.sh` compiles the real shim twice: installed-version
behavior and a **test-translation-unit-only** historical 4.5.4 version selection.
Both link the installed native runtime, not an actual legacy OpenCV library.
The installed 4.10 test accepts all-65535 UInt16 Gray for every pattern and
checks UInt16/C1/geometry, white pixels including borders, and Source preservation.
The legacy-branch test rejects before demosaicing, preserves sentinel bytes,
metadata and storage identity (including same-handle rejection), recovers at
sum 223300, and proves that a safe Region inside a bright parent succeeds.
This verifies the binding guard/publication path, **not runtime behavior of an
installed 4.1 or 4.5.4 library**. The focused CI steps run both variants.

### Local build environment

Normal `alr -n build` and `alr -n -C tests run` were attempted but blocked
before compilation by the host's pkg-config/sudo system-package deployment.
Used configure_opencv.sh and the selected Alire-managed GNAT 16.1.0/GPRbuild
26.0.1 fallback, with clean detached Core main
`99867564ad5d4560a95ed18038104771a1673ac6` and cached Alire AUnit 26.
Production dependency metadata and the unrelated sibling Core work were
not modified. Forced project-owned compilation used
`-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror`; strict C++ used
`-Wall -Wextra -Wpedantic -Werror`. GNATformat checks of all eight modified
Ada files, direct 79-column checks, and git diff --check passed for the original
feature. This corrective changes no Ada files; GNATformat and direct 79-column
checks of the existing Bayer Ada test/fixture units also pass. The strict
corrective library/test rebuild and full AUnit run again pass with **730 run,
730 successful, zero failed assertions and zero unexpected errors**. The native
tests pass with all four strict C++ warning switches, and the allocation-free
test additionally passes AddressSanitizer/UndefinedBehaviorSanitizer.