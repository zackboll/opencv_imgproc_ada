# Portable packed YUV 4:2:2: exact-tag source review

## Evidence and execution limits

Reviewed exact upstream checkouts, not moving main:

| Tag | Commit |
|---|---|
| [4.1.0](https://github.com/opencv/opencv/tree/4.1.0) | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| [4.10.0](https://github.com/opencv/opencv/tree/4.10.0) | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| [5.0.0](https://github.com/opencv/opencv/tree/5.0.0) | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

For **each tag**, inspected:

- `modules/imgproc/include/opencv2/imgproc.hpp`;
- `modules/imgproc/src/color.cpp`, `color.hpp`, `color.simd_helpers.hpp`;
- `modules/imgproc/src/color_yuv.dispatch.cpp`, `color_yuv.simd.hpp`;
- `modules/imgproc/include/opencv2/imgproc/hal/hal.hpp`;
- `modules/imgproc/src/hal_replacement.hpp`.

Also searched all in-tree vendor registrations for ordinary/Approx
`cv_hal_cvtOnePlaneYUVtoBGR`, and inspected 4.x
`3rdparty/openvx/hal/{openvx_hal.cpp,openvx_hal.hpp}`, Carotene registration
and color conversion source, and 5.0
`hal/{riscv-rvv,carotene,fastcv,ipp,armpl,kleidicv,ndsrvp}`.
RVV evidence is `hal/riscv-rvv/include/imgproc.hpp` and
`hal/riscv-rvv/src/imgproc/color.cpp`. Core luma/copy/allocation context includes
`modules/core/src/{channels.cpp,matrix_iterator.cpp,precomp.hpp,matrix.cpp}`.
Default-hint context is 5.0 `modules/core/src/system.cpp` and `CMakeLists.txt`.

Local runtime validation is **OpenCV 4.10.0, Linux x86_64**. No 4.1.0 or
5.0.0 runtime execution, RVV, OpenVX, Carotene, or other vendor execution is
claimed. Exact-header syntax checking is source compatibility evidence, not
linking/runtime verification. Remote CI uses its installed native versions.

## Public declaration and portable scope

4.1 and 4.10 declare `cvtColor(InputArray, OutputArray, int code, int dstCn=0)`.
5.0 appends `AlgorithmHint hint=ALGO_HINT_DEFAULT`. The binding uses the
ordinary default call, creates local `cv::Mat` output, and never exposes hints.

All three headers contain the following canonical decode mappings:

| Layout | BGR | RGB | BGRA | RGBA | Raw Y |
|---|---|---|---|---|---|
| UYVY | `COLOR_YUV2BGR_UYVY` | `COLOR_YUV2RGB_UYVY` | `COLOR_YUV2BGRA_UYVY` | `COLOR_YUV2RGBA_UYVY` | `COLOR_YUV2GRAY_UYVY` |
| YUY2 | `COLOR_YUV2BGR_YUY2` | `COLOR_YUV2RGB_YUY2` | `COLOR_YUV2BGRA_YUY2` | `COLOR_YUV2RGBA_YUY2` | `COLOR_YUV2GRAY_YUY2` |
| YVYU | `COLOR_YUV2BGR_YVYU` | `COLOR_YUV2RGB_YVYU` | `COLOR_YUV2BGRA_YVYU` | `COLOR_YUV2RGBA_YVYU` | `COLOR_YUV2GRAY_YUY2` |

UYVY's historical **Y422/UYNV** names alias its codes; YUY2's **YUYV/YUNV**
names alias YUY2. YVYU has its own canonical name, with Gray aliasing YUY2.
Aliases are not separate Ada layouts. VYUY constants are commented out, not
active declarations; no VYUY support is invented.

The 4.1 header has no RGB/BGR/BGRA/RGBA-to-packed-YUV422 codes. 4.10 and
5.0 expose **143..154** for UYVY/YUY2/YVYU encoding. Encoding is available
only in newer OpenCV releases and intentionally deferred from the portable
4.1/4.10/5.0 baseline. No version-gated public encoding API is introduced.
YUV420 is unchanged; planar/three-plane 4:2:2, 10/12/16-bit YUV, full range,
custom matrices, BT.709/2020 selection and UMat are out of scope.

## Bytes, pair semantics and output

Source is **UInt8 C2, H rows, W columns**, H>=1, even W>=2. Each C2 element
represents two consecutive stream bytes, not two colors or a four-byte pixel:

| Layout | Stream for two pixels | Column 0 C2 | Column 1 C2 | yIdx | uIdx |
|---|---|---|---|---|---|
| UYVY | U,Y0,V,Y1 | U,Y0 | V,Y1 | 1 | 0 |
| YUY2 | Y0,U,Y1,V | Y0,U | Y1,V | 0 | 0 |
| YVYU | Y0,V,Y1,U | Y0,V | Y1,U | 0 | 1 |

`color.cpp` selects yIdx; `color.hpp::uIndex`, `swapBlue`, `dstChannels`
select chroma, order and channel count. Native pair code calculates
`uidx=1-yIdx+2*uIdx`, `vidx=(2+uidx)%4`, loads two independent Y samples,
and reuses the same U/V. CPU dispatch templates accept exactly
`[uIdx,yIdx]=[0,0],[0,1],[1,0]`, C3/C4 and blue index 0/2.

Result geometry is H x W, UInt8. Repository outputs map as:

| Ada output | Channels | Byte order |
|---|---:|---|
| BGR_Output | 3 | B,G,R |
| RGB_Output | 3 | R,G,B |
| BGRA_Output | 4 | B,G,R,255 |
| RGBA_Output | 4 | R,G,B,255 |

CPU `yRGBuvToRGBA`/`cvtYuv42xxp2RGB8` and vector stores set alpha to 0xff.
RVV independently sets 0xff. OpenVX's RGBX destination follows the native
conversion contract; vendor runtime behavior was not executed locally.
Every binding result owns fresh Core storage and every input stays unchanged.

Private selectors are layout 0 UYVY, 1 YUY2, 2 YVYU and output 0 BGR,
1 RGB, 2 BGRA, 3 RGBA. A single table contains decode and luma codes.
Selectors reject before table indexing; no native COLOR_* integers cross Ada/C.
Public `YUV422_Color_Output` is a subtype of `YUV420_Color_Output`, not a
duplicate enumeration or a rename of the established YUV420 API.

## Raw Y extraction

All three `color.cpp` sources route Gray to `cvtColorYUV2Gray_ch`:
UYVY uses channel 1; YUY2/YVYU use channel 0. That wrapper asserts UInt8 C2
and invokes **Core `extractChannel`**, not color arithmetic. No subtract-16,
normalization, range rejection, or chroma participation exists.

The binding snapshots C2 and converts **one row at a time** into the local C1
result using the native Gray code. This avoids Core `mixChannels` collapsing
an entire continuous frame and then casting `it.size` to `int`. Its signed
`t+=blocksize` (BLOCK_SIZE=1024 for UInt8) final increment is safe per row
because W<=INT_MAX/2. IPP `llwiCopyChannel` narrows both steps to int;
packed snapshot W*2 and C1 output W fit. Original parent step never reaches
IPP. Raw luma intentionally allows odd widths; only thick Ada enforces the
complete even-width YUV422 frame contract. No claim is made that
`extractChannel` requires even width for memory safety.

## Limited-range arithmetic and pinned examples

All tags use the same portable CPU **20-bit fixed-point** decoder as YUV420:

```
CY = 1220542   CUB = 2116026   CUG = -409993
CVG = -852492  CVR = 1673527   SHIFT = 20
L = max(0, Y-16) * CY
R = saturate_u8((L + CVR*(V-128)                 + 524288) >> 20)
G = saturate_u8((L + CVG*(V-128) + CUG*(U-128)  + 524288) >> 20)
B = saturate_u8((L + CUB*(U-128)                 + 524288) >> 20)
```

This is limited-range BT.601-style arithmetic, approximately 1.164 Y,
1.596 V for R, -0.813 V/-0.391 U for G, and 2.018 U for B. Nominal Y is
16..235, U/V 16..240 centered at 128. All UInt8 values are accepted. Below-16
Y is clamped before chroma addition, then each color saturates to 0..255.
Production performs no color conversion in Ada.

Independent test expectations (R,G,B) calculated from these constants:

| Y | U | V | RGB |
|---:|---:|---:|---|
| 16 | 128 | 128 | 0,0,0 |
| 235 | 128 | 128 | 255,255,255 |
| 32 | 90 | 200 | 134,0,0 |
| 100 | 90 | 200 | 213,54,21 |
| 180 | 90 | 200 | 255,147,114 |
| 0 | 0 | 255 | 203,0,0 |
| 255 | 0 | 255 | 255,225,20 |

Fixtures set C2 elements directly from Y0/Y1/U/V records, without encoding or
production selectors. Pair tests use distinct Y0/Y1 and asymmetric U/V,
independently asserting each pixel in every output form. Wide frames cross
SIMD and scalar tails and the parallel threshold. General vendor/build pixel
identity is not promised; the installed algorithm and default hint are retained.

## The OpenCV 4.1 odd-width defect

4.1 `color_yuv.dispatch.cpp:340..345` constructs
`CvtHelper<Set<2>,Set<3,4>,Set<CV_8U>>`, with SizePolicy NONE. Its
`color.simd_helpers.hpp` has only TO_YUV/FROM_YUV/NONE: no YUV422
even-width policy. It checks channels/depth but not even width.

4.1 `YUV422toRGB8Invoker` (`color_yuv.simd.hpp:1672..1781`) loops
`for (; i < 2*width; i += 4, row += dcn*2)`. If W is odd, the final i is
`2*(W-1)`. For UYVY it reads V at i+2 and Y1 at i+3, beyond the 2W-byte
logical row; for YUY2/YVYU it reads Y1 at i+2 and the missing chroma at i+3.
It also writes two pixels with only one output column remaining. A parent
allocation may mask a read overrun, but the final row and local output can
overrun actual storage. Snapshotting alone does **not** repair odd geometry.

4.10 `color_yuv.dispatch.cpp:409..414` and 5.0 `:450..455` add
**FROM_UYVY**. Their `CvtHelper` asserts `sz.width%2==0` and preserves size.
The binding rejects W=1/3/5 before native entry on **every** supported version;
the raw decode even-width duplicate is an explicit ABI-safety condition, not
merely a friendly semantic check.

## Signed arithmetic, addresses and allocations

`cpp/yuv422_layout_fits.hpp` uses constexpr **uint64_t**, division-before-
multiplication predicates shared by production and allocation-free tests:

1. W>=2 and even protects the 4.1 complete-pair reads/writes.
2. **W<=INT_MAX/2** protects native signed `2*width`, both SIMD
   `i<=2*width-4*vsize` and scalar `i<2*width`. It also bounds the final i+=4
   because an even width makes 2W a multiple of 4 <= INT_MAX-3.
3. **H<=INT_MAX/W** protects signed CPU `width*height>=320*240`,
   OpenVX `w*h` small-image routing and RVV `(width-1)*height` scheduling.
   This is UB prevention, not a harmless scheduling approximation.
4. Snapshot H*W*2 and decode H*W*dcn/C1 H*W allocation spans must fit
   **min(PTRDIFF_MAX,SIZE_MAX)**. Row bytes and complete spans are separately
   covered using divisions, without forming overflowing products first.
5. Original logical readable span `(H-1)*source_step+W*2` fits the same
   limit; step>=row_bytes. One-row sources need no bound on an unused parent
   step. No arbitrary INT_MAX restriction is placed on original parent strides.
6. Reachable **4.x OpenVX** UYVY/YUY2 RGB/RGBA, after its small-image
   threshold `W*H>=2048*1536`, needs **W<=INT_MAX/dcn** for its output
   step cast to vx_int32 and H=1 signed `refineStep` product. BGR/BGRA and
   YVYU reject before those operations and need no duplicate row restriction.
   Source snapshot step W*2 already fits int. The predicate uses a widened
   threshold division, not signed W*H; no arbitrary parent step reaches it.
7. Raw luma's W<=INT_MAX/2 protects IPP steps and per-row mixChannels
   counter arithmetic, but it needs neither evenness nor signed W*H bounds.

No giant boundary-test allocation is required. Static assertions cover minimum,
odd/zero widths, last even 2W-fitting width/next even failure, the INT_MAX-side
W*H boundary, exact C2/C3/C4 spans, exact parent span, large representable
parent step, invalid output channels, luma envelope, and OpenVX output limits.

## SIMD and RVV evolution

4.1 universal SIMD uses `v_uint8::nlanes`, array temporaries and zipped
two-Y streams. 4.10/5.0 use `CV_SIMD || CV_SIMD_SCALABLE`,
`VTraits<v_uint8>::vlanes()`, explicit vector temporaries and universal
intrinsics. All retain shared U/V, two independent Y vectors, rounding bias,
opaque alpha, pair scalar tail, size_t row steps and signed 2W/W*H expressions.

Exact **5.0.0 RVV** registers ordinary `cv_hal_cvtOnePlaneYUVtoBGR`.
`PlaneYUVtoBGR::cvtSinglePlaneYUVtoBGR` calculates the same uidx/vidx,
segments four bytes per pair, selects Y0/Y1, and supports all three layouts.
`cvtOnePlaneYUVtoBGR` accepts C3/C4 and both swapBlue orders. The converter
uses `dst_width/2` pairs, `4*i` offsets, size_t source/destination steps,
and row-start `start*stride`/`j*dst_step`. Even width guarantees no dropped
pixel. The 2W bound protects signed `4*i`; W*H protects its scheduler.
`color::invoke` uses Range(1,H) plus an explicit first-row call, so H=1
is supported.

RVV coefficients/bias match CPU exactly. It clamps Y-16 at zero, adds the
same bias, uses `vnclip` with **RDN** after adding that bias, clamps negatives,
and saturates to UInt8; no additional nearest-rounding step is introduced.
C4 alpha is 0xff. Source arithmetic supports equivalence; **runtime RVV
validation was not executed**, and no global vendor pixel identity claim is made.

## Reachable in-tree HAL/vendor audit

| Route | 4.1.0 | 4.10.0 | 5.0.0 |
|---|---|---|---|
| Packed decode | ordinary HAL, CPU dispatch | ordinary HAL, CPU dispatch | Approx-if-requested HAL, ordinary HAL, CPU dispatch |
| OpenVX | UYVY/YUY2 RGB(A) subset | same subset | no in-tree OpenVX HAL |
| RVV HAL | absent | absent | all selected layouts/C3/C4/orders |
| Gray | Core extractChannel/IPP | same | same |

- **OpenVX 4.x** registers one-plane YUV decoding. It declines small frames,
  unsupported vendor dimensions, !swapBlue (BGR/BGRA), uIdx=1 (YVYU), and
  odd W. UYVY/YUY2 create UYVY/YUYV handles, RGB/RGBX results, with
  size_t steps narrowed to vx_int32. It may decline full-range image handles
  before conversion. Both step casts and signed one-row refineStep were audited;
  the shim snapshots and precisely guards only reachable RGB(A) output rows.
  Khronos/default vendors also impose their own dimension rejection; other
  vendors can reach the cast for larger widths, so that guard remains necessary.
  The guard is enabled only for native major versions below 5; 5.0 does not
  inherit an unnecessary output-int-step restriction from the absent HAL.
  No opaque external vendor's pixel rounding is claimed identical.
- **Carotene 4.x/5.0** has no one-plane-YUV422 HAL registration. Its
  semiplanar YUV420 converters and ptrdiff_t steps are unrelated and unreachable
  here. They do not justify limiting the original YUV422 parent stride.
- **5.0 FastCV** ordinary/Approx color registrations do not replace this
  one-plane decoder. Its other uint32_t strides are unreachable here.
- **5.0 IPP, ArmPL, KleidiCV, NDSRVP** register no ordinary or Approx
  one-plane YUV422 decoder in these exact sources. No uint32/int narrowing
  guard is added for unrelated operations. IPP code inside color_yuv dispatch
  serves other color families; the packed decoder directly calls HAL/CPU.
- **Core IPP luma** is reachable through extractChannel and narrows steps to
  int. Snapshot and row-wise extraction satisfy the exact needed limits.
- **Default hal_replacement** returns NOT_IMPLEMENTED, falling through to
  CPU dispatch. Source/HAL and CPU steps are size_t. No one-plane Approx
  replacement is registered in the exact 5.0 in-tree HALs.

## AlgorithmHint and OpenCL

5.0 `cvtColor` resolves DEFAULT via `getDefaultAlgorithmHint`: ACCURATE
unless CMake `OPENCV_ALGO_HINT_DEFAULT` selects APPROX. The one-plane
wrapper passes the resolved hint; Approx is tried first only when requested,
then ordinary HAL/CPU runs. Exact 5.0 has no in-tree YUV422 Approx replacement,
so no in-tree byte-layout/alpha blocker was found. External HAL replacements
and future/build-specific implementations can differ numerically; the binding
does not force ACCURATE or promise vendor/build pixel identity.

All three `color.cpp` sources gate OpenCL on `_dst.isUMat()` (and source
dims<=2). This binding publishes a **local Mat**, so the OpenCL YUV422 path
is unreachable. Core luma's UMat branch is likewise unreachable. No UMat
or global backend toggle is introduced.

## Snapshot, Region and boundary ownership review

Before native entry: validate handles/selectors and byte layout; preflight
arithmetic, allocation and original readable spans; allocate independent C2;
**memcpy logical W*2 rows**; call native conversion; move the local result
into destination only after success. No clone/copyTo routes parent strides
through optional narrowing. Source and destination can be the same borrowed
handle: snapshot completes first. Failed calls preserve destination metadata,
pixels and storage identity, and normal calls recover after failures. Existing
exception translation contains OpenCV, standard and unknown C++ exceptions.

Regions describe **standalone frames with caller-supplied byte phase**. No
parent offsets or outside pixels participate. An odd-column ROI can alter the
parent's U/V phase; the binding neither inspects that origin nor rewrites Layout.
Tests deliberately populate complete logical Regions at odd parent columns.
Core remains the sole owner of Mats; the public API exposes no handles.

Retained duplicated conditions and concrete **ABI safety** reasons:

- nonempty 2-D UInt8 C2: manual row-copy bounds and native byte-pair
  interpretation, preventing use of invalid dimensions/storage widths;
- even W>=2 in decode only: OpenCV 4.1 incomplete-pair read and output overrun;
- widened signed arithmetic, vendor step and address/allocation preflights:
  prevent overflow, truncation and out-of-bounds pointer formation;
- luma snapshot-row envelope: IPP int step narrowing and mixChannels counters.

All such checks carry ABI-safety comments. Luma does not duplicate the public
even-width semantic condition. No output postconditions merely restating native
semantics are added. Unknown selectors protect table bounds rather than defining
a second public policy layer.

## Verification

Baseline: **780 registered/executed/passed**. Added **32 focused AUnit tests**;
final **812 registered, 812 executed, 812 passed**, zero failed assertions,
zero unexpected errors locally on installed 4.10.0. Tests cover all layouts and
outputs/alpha, independently pinned pairs, out-of-studio saturation, raw patterned
luma/chroma independence, minimum frames, W=1/3/5 rejection, Regions, fresh
storage, raw invalid selectors/nulls/types/ND/odd widths, failure storage identity,
recovery, same-handle decode/luma and SIMD/scalar/parallel-size frames.
Unallocatable raw arithmetic boundaries are tested by the production constexpr
helper rather than fabricated invalid Mat headers or giant allocations.

The allocation-free helper passes `-std=c++17 -Wall -Wextra -Wpedantic -Werror`
and ASan/UBSan locally; CI integrates it on Linux, macOS and Windows main/manual
events. Strict library and project-owned Ada tests use
`-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror`.
Strict C++ uses `-Wall -Wextra -Wpedantic -Werror`.

The final shim passes strict syntax-only compilation against exact public
Core/Imgproc headers from **4.1.0, 4.10.0 and 5.0.0**, supplying installed
generated configuration headers where needed. This is not equivalent to linking
or runtime testing those versions.

Normal Alire commands were attempted but blocked before compilation by the
existing pkg-config/sudo host deployment issue. The fallback uses
`scripts/configure_opencv.sh`, Alire-managed GNAT 16.1.0/GPRbuild 26.0.1 and
cached AUnit 26, with clean detached Core
`d031fbcc02c3f493adf954a18497c0d1e592c846`. No production dependency metadata
or unrelated Core work is changed. GNATformat and direct 79-column checks cover
all modified Ada. No SPARK-compatible code was materially changed; proof and
coverage tools are not required for this native slice. Runtime validation is Ada
checks/tests, arithmetic safety is constexpr evidence, and foreign algorithms are
trusted based on source review and testing, not claimed formally proven.