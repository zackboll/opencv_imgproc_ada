# Portable YUV 4:2:0: exact-tag source review

## Evidence and execution limits

Reviewed the exact upstream OpenCV Git tags, not moving branches:

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

Inspected vendor registration and implementations separately, including 4.x
`3rdparty/carotene/{hal/tegra_hal.hpp,src/colorconvert.cpp}`, 4.x
`3rdparty/openvx/hal/{openvx_hal.hpp,openvx_hal.cpp}`, and 5.0
`hal/{carotene,fastcv,riscv-rvv,ipp,kleidicv,armpl,ndsrvp}`. Carotene moved
from `3rdparty` to `hal` in 5.0. RVV's relevant implementation is
`hal/riscv-rvv/src/imgproc/color.cpp`, registration `include/imgproc.hpp`.
Also inspected Core `copy.cpp`, allocation/layout context, 5.0
`modules/core/src/system.cpp`, and CMake default-hint configuration.

Local AUnit runtime execution is **installed OpenCV 4.10.0 on Linux x86_64**.
No 4.1.0/5.0.0, ARM/Carotene, RVV, OpenVX, IPP-enabled, or OpenCL runtime
verification is claimed. Source review is not equivalent to native execution.

## Native public surface and mappings

All three headers expose `cvtColor(InputArray, OutputArray, int code,
int dstCn=0)` and `cvtColorTwoPlane(InputArray, InputArray, OutputArray,
int code)`. 5.0 appends `AlgorithmHint hint=ALGO_HINT_DEFAULT` to both.
The binding uses the normal portable calls, without version-specific hints.

These conversion names are shared by **all three** exact headers:

| Layout | BGR | RGB | BGRA | RGBA |
|---|---|---|---|---|
| I420 | `COLOR_YUV2BGR_I420` | `COLOR_YUV2RGB_I420` | `COLOR_YUV2BGRA_I420` | `COLOR_YUV2RGBA_I420` |
| YV12 | `COLOR_YUV2BGR_YV12` | `COLOR_YUV2RGB_YV12` | `COLOR_YUV2BGRA_YV12` | `COLOR_YUV2RGBA_YV12` |
| NV12 | `COLOR_YUV2BGR_NV12` | `COLOR_YUV2RGB_NV12` | `COLOR_YUV2BGRA_NV12` | `COLOR_YUV2RGBA_NV12` |
| NV21 | `COLOR_YUV2BGR_NV21` | `COLOR_YUV2RGB_NV21` | `COLOR_YUV2BGRA_NV21` | `COLOR_YUV2RGBA_NV21` |

Encode names are `COLOR_{BGR,RGB,BGRA,RGBA}2YUV_I420` and the same four
`..._YV12` names. I420 decode names alias IYUV. `COLOR_YUV2GRAY_420` and
its layout aliases all share the same raw-Y extraction. No native enum integer
crosses the private ABI. Repository selectors are layout 0 I420, 1 YV12,
2 NV12, 3 NV21; output 0 BGR, 1 RGB, 2 BGRA, 3 RGBA; order 0 BGR/BGRA,
1 RGB/RGBA. Pair accepts 2..3; encode accepts 0..1; invalid selectors reject.

`color.hpp::dstChannels`, `swapBlue`, and `uIndex` establish the mappings.
Decode chooses blue index 0 for BGR/BGRA and 2 for RGB/RGBA. Output is
UInt8 C3 or C4 H x W. CPU scalar `yRGBuvToRGBA` assigns `a=0xff`; SIMD
stores a vector of 0xff. Carotene `fillAlpha<4>` also assigns 255.
Encode C3 BGR/RGB and C4 BGRA/RGBA read the same first three components;
SIMD loads alpha only as an unused deinterleave output. Alpha is ignored,
never validated for opacity or premultiplied.

## Layout, depth and stride

Packed inputs/results have **W columns and H+H/2 rows, UInt8 C1**.
Logical W/H are even and >=2. I420's flat stream is Y then U then V;
YV12 exchanges U/V. Each chroma plane contains W*H/4 bytes. This is a flat
stream, not necessarily an integral number of full Mat rows per chroma plane:
H=2 mod 4 starts the second chroma plane halfway through a packed row.
`cvtThreePlaneYUVtoBGR` computes that offset using `H+H/4` and `W/2`.
`ustepIdx/vstepIdx` alternate W/2-sized halves when traversing chroma rows.
The independent test reader uses stream offsets, not decode or selector tables.

NV12's stream is Y then U,V pairs; NV21 is Y then V,U pairs. Separate planes
have Y UInt8 C1 H x W, UV UInt8 C2 H/2 x W/2: both packed row byte counts
are W. The native pair entry checks Y depth and dimension relationships but
does **not** independently enforce UV channels/depth. Raw checks protect that
byte-pointer interpretation. The binding accepts no alternative chroma shape.

All native packed CvtHelper instantiations use `Set<CV_8U>`, source C1 for
decode/luma, C3/C4 for encode. No UInt16/Float32 or high-bit-depth mode is added.

### Exact cross-version pair difference

- **4.1.0:** `cvtColorTwoPlaneYUV2BGRpair` passes `ysrc.step` as the **single
  stride for both Y and UV**. Its pair HAL overload is CPU dispatch only.
- **4.10.0/5.0.0:** pair compares steps. Equal steps use the shared-step
  overload; unequal steps call the independent-step overload. The shared-step
  overload forwards to the independent-step implementation.

Both binding forms of NV12/NV21 intentionally use **cvtColorTwoPlane**.
Packed semiplanar input is first snapshotted, then its logical Y and UV bytes
are copied into independent packed C1/C2 Mats. Separate planes each get a deep
packed snapshot. All Y and UV steps are W, so 4.1 receives its assumed layout.
This is **both stride and semantic-route normalization**, not merely rejection
of differently-strided Regions. Equivalent forms produce identical pixels.

**Important tradeoff:** 4.1 packed `cvtColor` can reach single-buffer
HAL/Carotene while its pair API bypasses it. The binding deliberately forgoes
that packed-only acceleration opportunity there. It does not claim to preserve
every vendor acceleration route. 4.10/5.0 pair HAL routing is expanded.
No global acceleration setting or backend switch is changed.
I420/YV12 and encode retain their natural `cvtColor` paths.

## Numeric contract

Portable CPU coefficients are unchanged across these tags. Shift is 20,
half-rounding offset is 524288, and results saturate to UInt8:

```text
L = max(0, Y-16) * 1220542
R = (L + 1673527*(V-128)                    + 524288) >> 20
G = (L - 852492*(V-128) - 409993*(U-128)     + 524288) >> 20
B = (L                  + 2116026*(U-128)  + 524288) >> 20
```

This is BT.601-style limited-range: nominal Y 16..235, Cb/Cr 16..240,
chroma center 128. Bytes outside nominal studio range are accepted, not
rejected. The below-16 Y clamp is native. There is no custom matrix, BT.709,
BT.2020, full-range, 10/12-bit, or public hint selection.

Encode is likewise 20-bit:

```text
Y = ( 269484*R + 528482*G + 102760*B + 16*1048576  + 524288) >> 20
U = (-155188*R - 305135*G + 460324*B + 128*1048576 + 524288) >> 20
V = ( 460324*R - 385875*G -  74448*B + 128*1048576 + 524288) >> 20
```

Black gives Y/U/V=16/128/128; white 235/128/128. Alpha is absent from these
expressions. The binding calls OpenCV; no production pixel arithmetic is Ada.

### Chroma sampling: scalar, SIMD, RVV

Reviewed `RGB8toYUV420pInvoker` independently in all tags. Scalar computes Y
for both horizontal pixels on every source row. Only `evenRow` writes chroma,
and it calls `rgbToUV42x(r0,g0,b0)` on pixel `2*i`, **the top-left sample of
each 2x2 block**, not four-pixel averaging.

Universal SIMD computes Y for every lane, then `rgbToUV42x` reinterprets paired
bytes as 16-bit lanes and masks with **0x00ff**, retaining only even horizontal
samples. Chroma writes still occur only on even rows. There is no average or
vertical blend. 4.1 uses operator expressions and fixed vector lane counts;
4.10/5.0 use intrinsic functions and `VTraits`/scalable lane support. The
coefficients, half shift, lane selection and scalar tails are equivalent.
5.0 RVV segment loads explicitly separate the two pixels and call UV conversion
only on `b0,g0,r0` for even rows, with the same coefficients and rounding.

Tests use a 4x4 distinct-color fixture and a 66x4 SIMD-plus-tail fixture in
both orders, C3/C4 and both plane layouts. Every Y and U/V byte is independently
checked, and changing unsampled pixels leaves U/V unchanged. No round trip is
used to infer plane order or sampled pixels. Arbitrary RGB round trips are
lossy; tests instead bound constant-color and near-neutral texture errors.

### Carotene difference (not a binding conversion implementation)

Carotene's YUV420 decoder uses COEFF_Y=149, BU=129, RV=102, GU=25, GV=52,
R offset=-14248, G offset=8663, B offset=-17705, with different staged shifts.
Its scalar tail computes green as
`((((149*max(16,Y))>>1)+8663-25*U-52*V)>>1)+16`, then shifts by 5 and
saturates. For **Y=32,U=90,V=16**, portable CPU green is **125** while
Carotene scalar-tail green is **124**. Its NEON implementation has its own
staged halving/narrowing; it is not generally bit-identical to portable CPU.
This difference exists in all reviewed Carotene sources.

In 4.1 it could make packed versus pair results different if the binding used
different public native entry points. The agreed common pair route removes
that representation-dependent difference. It does **not** promise pixel
identity across different versions/vendor configurations. Exact decode tests
use stable black/white/asymmetric scalar-tail samples; the spatial pair
cross-check includes the differing sample and asserts equality of the two
selected native routes, not equality to a universal CPU oracle.

## Luma is raw data, not colorimetry

`cvtColorYUV2Gray_420` creates H x W C1 with FROM_YUV, then copies the first
H rows. Optional IPP `ippiCopy_8u_C1R_L` uses `IppSizeL` steps. The fallback
takes `Range(0,H)` and `copyTo`. No limited-range subtraction, scaling or
chroma read participates. Snapshots make its source/destination step W<=INT_MAX,
also safe for Core copy paths that narrow steps to int. Tests check patterned
Y containing 0/16/235/255 byte-for-byte in every layout and vary chroma freely.

## Native arithmetic and allocation audit

`cpp/yuv420_layout_fits.hpp` implements pure constexpr widened predicates used
before allocations and independently exercised by allocation-free static_asserts.
There are no giant allocation tests and no arbitrary practical size limits.

1. **Packed rows:** nonempty, rows divisible by 3 and width even. Logical H is
   `(packed_rows/3)*2`, never signed `rows*2/3` in the binding.
2. **FROM_YUV:** all three `CvtHelper` sources evaluate signed
   `sz.height*2/3`. Packed decode/luma preflight `packed_rows<=INT_MAX/2`,
   including semiplanar for a consistent portable packed safety envelope.
3. **TO_YUV:** native `(H/2)*3` must fit INT_MAX. Check `H/2<=INT_MAX/3`.
4. **Scheduling:** portable planar and semiplanar decode and encode evaluate
   signed `W*H>=320*240`. Preflight `W<=INT_MAX/H`. OpenVX small-image routing
   also uses signed W*H; RVV scheduling uses `(W-1)*H`. The same bound covers
   these. Luma does not reach YUV converter scheduling and does not need W*H
   signed-int bounds, only allocation/address spans.
5. **Encoder scalar indices:** maximum first-three-component index is
   `(W-1)*scn+2`, since `i<=W/2-1`. Require
   `W-1<=(INT_MAX-2)/scn`. For C3 this is W*3-1; for C4 W*4-2. Ignored alpha
   does not require a stricter W*4 bound. SIMD load starts are smaller and
   their vector spans stay inside the row. No arbitrary width cap is used.
6. **Encoder row additions:** planar UV positioning uses signed `sRow+H`;
   maximum evaluated even sRow is H-2. With W>=2 and W*H<=INT_MAX,
   `2*H-2<=INT_MAX` follows. Pair-loop `range.end*2` also fits H.
7. **Planar stride cast:** native `int uvsteps[2]={W/2,int(stride)-W/2}`.
   Snapshot stride is **W<=INT_MAX**, so the cast and subtraction are safe.
   No arbitrary parent step reaches this path. RVV has the same cast.
8. **Pair assertions:** native evaluates signed `uv_width*2` and
   `uv_height*2`. Check UV extents <=INT_MAX/2 and the relationships in
   widened arithmetic before native entry.
9. **Vendor decode output strides:** OpenVX narrows packed RGB/RGBX step
   to vx_int32. Require `W<=INT_MAX/dcn` before decode allocations. This
   protects reachable I420 RGB(A) and 4.10 separate-plane RGB(A) routes.
   Carotene steps are ptrdiff_t, protected by the address-span limit.
10. **Encode vendor stride:** OpenVX encode rejects `uIdx!=0` before casting;
    I420 encode has uIdx=1 and YV12=2, so both exposed codes fall back. No
    reachable OpenVX encode cast necessitates tightening the exact C4 index
    bound. 5.0 RVV uses size_t steps; it does not narrow this source row step.
11. **Address/allocation sizes:** row bytes and complete packed source, Y, UV C2,
    RGB source, decode output and packed encode output spans must fit
    `min(PTRDIFF_MAX,SIZE_MAX)`. Divide before multiplying. Original parent
    readable span `(rows-1)*step+row_bytes` is checked similarly before memcpy.
    Wide parent steps are not themselves restricted to int. OOM translates
    as an ordinary native exception. The helper accepts a simulated address
    limit for 32-bit/exact-boundary tests without allocations.
    Reviewed Core `MatAllocator::allocate` multiplies sizes in size_t;
    these complete-span checks precede it. `fastMalloc` fallback adds a
    pointer slot plus alignment padding: PTRDIFF_MAX leaves sufficient
    size_t headroom on supported 32/64-bit targets, preventing wrap there.

## HAL and vendor reachability: separate from ordinary C3 YUV

| Path | 4.1.0 | 4.10.0 | 5.0.0 |
|---|---|---|---|
| Native packed NV12/NV21 cvtColor | single-buffer HAL then CPU | single-buffer HAL then separate-step HAL/CPU | approximate-if-requested HAL, ordinary HAL, separate-step HAL/CPU |
| **Binding packed NV12/NV21** | pair CPU dispatch | pair Ex HAL/CPU | pair Ex HAL/CPU |
| Binding separate NV12/NV21 | shared-step pair CPU dispatch | shared-step forwards Ex HAL/CPU | shared-step forwards Ex HAL/CPU |
| Packed I420/YV12 decode | three-plane HAL/CPU | three-plane HAL/CPU | hint plumbing, three-plane HAL/CPU |
| I420/YV12 encode | BGR-to-three-plane HAL/CPU | BGR-to-three-plane HAL/CPU | hint plumbing, BGR-to-three-plane HAL/CPU |
| Luma | optional IPP copy or Core copyTo | same | same |

- **Carotene:** registers only packed semiplanar YUV420 decode in 4.1, plus
  Ex separate-step decode in 4.10/5.0. No planar decoder/encoder registration.
  It accepts C3/C4, both orders and UV orders; alpha is 255. Step parameters
  are ptrdiff_t, so packed byte-span checks cover its narrowing. Its rounding
  differences are intentionally documented above, not silently corrected.
- **OpenVX 4.x:** registers packed/three-plane decode and encode; 4.10 adds
  Ex pair decode. Small frames (<2048*1536) fall back. RGB/RGBX only, planar
  I420 decode only, and compact chroma addressing required. Packed stride
  normalization satisfies that addressing; row-step vx_int32 casts have
  explicit bounds. Limited/full range support can cause fallback. Both native
  encode codes exposed here have nonzero uIdx and reject before vendor entry.
  This HAL is absent from the 5.0 in-tree HAL list. No opaque external OpenVX
  implementation's numeric behavior is asserted to match portable CPU.
- **5.0 RVV:** registers packed semiplanar decode, three-plane decode/encode,
  but not Ex separate-plane decode. Consequently binding NV12/NV21 reaches
  universal CPU dispatch, not that packed-only RVV HAL. I420/YV12 can reach
  it; coefficient/sample equivalence and size_t offsets were source-reviewed.
- **FastCV 5.0:** registers ordinary C3 BGR-to-YUV Approx, not this family's
  two/three-plane or Ex HALs. Its uint32 narrowing for other operations is
  unreachable from these new paths. Do not conflate it with YUV420.
- **5.0 IPP/ArmPL/KleidiCV/NDSRVP:** registration inspection found no
  relevant two/three-plane YUV420 replacement for these routes. Generic HAL
  replacement defaults return NOT_IMPLEMENTED and then CPU dispatch runs.
- **IPP in color_yuv.dispatch.cpp:** the RGB/YUV conversion functors belong
  to **ordinary C3 YUV**, not planar/semiplanar 420. No 420 color IPP functor
  is used. The only relevant direct IPP call is raw luma copy. Snapshot memcpy
  deliberately avoids optional clone/copyTo parent-step narrowing.

Custom out-of-tree HAL replacements remain part of the installed native
implementation; the binding does not implement an independent color algorithm.

## OpenCL and OpenCV 5 hints

All three `cvtColor` sources guard OpenCL with `_dst.isUMat()` (and <=2 source
dimensions). Outputs here are **local cv::Mat**, so the YUV420 OpenCL kernels
are unreachable. The pair public entry does not contain an OpenCL dispatch.
There is no UMat support in this slice.

5.0 `cvtColor` resolves DEFAULT using `getDefaultAlgorithmHint()`. Core returns
ACCURATE unless `OPENCV_ALGO_HINT_DEFAULT` is configured to APPROX. Approximate
two/three-plane HAL hooks are attempted only when hint==APPROX, followed by
ordinary HAL and CPU. In-tree FastCV Approx registration targets C3 YUV only;
none of the reviewed 420 replacement registrations supplies these Approx hooks.

**5.0 cvtColorTwoPlane does not resolve DEFAULT in its entry.** It forwards
DEFAULT to the pair helpers; the `hint==APPROX` branches therefore do not run
for this binding's normal pair call, even with the configured global default.
Ordinary Ex HAL/CPU can still run. No in-tree default approximate 420 path
materially changing the sampled-pixel contract was found. No public hint,
forced ACCURATE argument, global acceleration switch, or version-only policy
is introduced.

## Snapshot, Region, ownership and validation-boundary review

Every new source form uses manual logical-row memcpy into a new packed Mat.
This matches Bayer's strategy without a broad refactor. Packed semiplanar
additionally gets independent Y and UV Mats before pair conversion. All
preflight predicates execute before allocation/native loops. Regions are
standalone buffers; no parent offsets, neighbor pixels, or chroma phase are
inferred. Callers must supply complete packed layouts or corresponding planes.

Core remains the sole Mat owner. Bridge handles are borrowed only during
callbacks; no competing Mat, retained handles, or ABI details enter public Ada.
Native output is local until successful publication by move. All failures leave
the destination header/pixels/storage unchanged. Same-handle publication is
supported for packed source, Y, UV, RGB encode source and luma source. No C++
exception crosses the boundary; existing thread-local status/message translation
handles OpenCV, standard and unknown exceptions.

Friendly public shape/depth/channel policy lives in Ada. **Retained duplicate
conditions have concrete ABI-safety reasons**, recorded at the checks/helpers:

- nonempty 2-D UInt8 C1 packed/Y, C2 UV and C3/C4 encode: snapshot row bounds
  and native byte/pixel-plane interpretation (native pair misses UV checks);
- even >=2 W/H, packed rows divisible by 3: complete 2x2 reads and safe plane
  offsets, not merely friendly diagnostics;
- matching half-size UV extents: native signed multiplication and byte bounds;
- widened native arithmetic, allocation/address spans and vendor stride limits:
  prevent signed overflow, truncation or out-of-bounds pointer formation.

Selector checks protect mapping-array bounds. No semantic output postconditions
or arbitrary practical image-size restrictions are added.

## Verification

Baseline **730 registered/executed/passed**. Added **50 focused AUnit tests**:
final **780 registered, 780 executed, 780 passed**, zero failed assertions and
zero unexpected errors. Fixtures build all packed layouts and C2 pair planes
without production encode. Plane readers do not use production decode.
Coverage includes all outputs, orders, minimum frames, out-of-studio bytes,
alpha, scalar/SIMD sampling, exact pair equality (including differently-strided
Regions), luma bytes, source preservation, fresh results, lossy round trips,
public rejection, raw selector/null/layout rejection, atomic sentinel storage,
recovery and same-handle publication.

`tests/yuv420_layout_test.cpp` passes strict C++ and ASan/UBSan locally; CI
runs it on Linux, macOS, and Windows after merge/manual dispatch. Native
4.1/5.0 runtime and vendor execution remain unverified locally.

Normal `alr -n build` and `alr -n -C tests run` were attempted but blocked
before compilation by pkg-config/sudo deployment. Used configure_opencv.sh,
cached Alire-managed GNAT 16.1.0/GPRbuild 26.0.1 and AUnit 26, with clean
detached Core `99867564ad5d4560a95ed18038104771a1673ac6`. Unrelated sibling
Core modifications and production dependency metadata remain untouched.
Strict Ada uses `-gnatwa -gnatwc -gnatwu -gnatwn -gnatwe -gnatyM79 -Werror`;
strict C++ uses `-Wall -Wextra -Wpedantic -Werror`. GNATformat and direct
79-column checks cover all modified Ada files. No SPARK-compatible helper was
materially changed; GNATprove/GNATcov were not run for this native algorithm
slice. Arithmetic safety is covered by constexpr boundary tests, runtime
contracts by Ada validation, foreign behavior by source review and AUnit.

The entire shim also passes strict syntax-only compilation against each exact
tag's Core/Imgproc public headers (installed generated configuration headers
supplied where needed). This checks source/API compatibility, **not linking or
runtime execution** against 4.1.0 or 5.0.0.