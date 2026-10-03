# Extended single-Mat color conversion source review

## Pinned evidence and scope

Reviewed exact OpenCV tags **4.1.0**, **4.10.0**, **5.0.0**, not moving branches.
Local execution uses installed **4.10.0** only. This review does not claim runtime
execution of 4.1.0, 5.0.0, IPP, ARM vendor libraries, or RISC-V HAL.

Authoritative roots (append the paths below):

- <https://github.com/opencv/opencv/tree/4.1.0>
- <https://github.com/opencv/opencv/tree/4.10.0>
- <https://github.com/opencv/opencv/tree/5.0.0>

For every tag inspected:

- `modules/imgproc/include/opencv2/imgproc.hpp`;
- `modules/imgproc/src/color.cpp` and `color.hpp`;
- `modules/imgproc/src/color_hsv.dispatch.cpp` and `color_hsv.simd.hpp`;
- `modules/imgproc/src/color_lab.cpp`;
- `modules/imgproc/src/color_rgb.dispatch.cpp` and `color_rgb.simd.hpp`;
- `modules/imgproc/src/color.simd_helpers.hpp`;
- `modules/imgproc/include/opencv2/imgproc/hal/hal.hpp`;
- `modules/imgproc/src/hal_replacement.hpp`.

Related existing RGB/Gray, XYZ, YCrCb/YUV fallback loops were also inspected
(`color_yuv.simd.hpp`) to establish the shared scheduling-product coverage.
Vendor files: 4.x `3rdparty/carotene/hal/tegra_hal.hpp`,
`3rdparty/carotene/src/colorconvert.cpp`, and Carotene function declarations;
5.0 corresponding files under `hal/carotene`; 5.0
`hal/fastcv/include/fastcv_hal_imgproc.hpp`,
`hal/fastcv/src/fastcv_hal_imgproc.cpp`, `3rdparty/fastcv/fastcv.cmake`;
5.0 `hal/riscv-rvv/include/imgproc.hpp` and
`hal/riscv-rvv/src/imgproc/color.cpp`. In-tree HAL replacement registrations
were searched for all six relevant color HAL entry points.

## Availability, selectors, channels and depths

All eighteen codes below occur in **all three** pinned `ColorConversionCodes`
declarations. Native enum numbers are deliberately not the binding ABI.
Private semantic selectors append **68..85**, preserving **0..67**.
Compile-time table length covers 0..85; 86, higher values and negatives reject.

| Public selector(s) | Private selector(s) | Native code(s) | Public channels | Depths |
| --- | --- | --- | --- | --- |
| `BGR_To_HSV_Full`, `RGB_To_HSV_Full` | 68, 69 | `COLOR_BGR2HSV_FULL`, `COLOR_RGB2HSV_FULL` | C3 -> C3 | UInt8, Float32 |
| `HSV_Full_To_BGR`, `HSV_Full_To_RGB` | 70, 71 | `COLOR_HSV2BGR_FULL`, `COLOR_HSV2RGB_FULL` | C3 -> C3 | UInt8, Float32 |
| `BGR_To_HLS_Full`, `RGB_To_HLS_Full` | 72, 73 | `COLOR_BGR2HLS_FULL`, `COLOR_RGB2HLS_FULL` | C3 -> C3 | UInt8, Float32 |
| `HLS_Full_To_BGR`, `HLS_Full_To_RGB` | 74, 75 | `COLOR_HLS2BGR_FULL`, `COLOR_HLS2RGB_FULL` | C3 -> C3 | UInt8, Float32 |
| `Linear_BGR_To_Lab`, `Linear_RGB_To_Lab` | 76, 77 | `COLOR_LBGR2Lab`, `COLOR_LRGB2Lab` | C3 -> C3 | UInt8, Float32 |
| `Lab_To_Linear_BGR`, `Lab_To_Linear_RGB` | 78, 79 | `COLOR_Lab2LBGR`, `COLOR_Lab2LRGB` | C3 -> C3 | UInt8, Float32 |
| `Linear_BGR_To_Luv`, `Linear_RGB_To_Luv` | 80, 81 | `COLOR_LBGR2Luv`, `COLOR_LRGB2Luv` | C3 -> C3 | UInt8, Float32 |
| `Luv_To_Linear_BGR`, `Luv_To_Linear_RGB` | 82, 83 | `COLOR_Luv2LBGR`, `COLOR_Luv2LRGB` | C3 -> C3 | UInt8, Float32 |
| `RGBA_To_Premultiplied_RGBA` | 84 | `COLOR_RGBA2mRGBA` | C4 -> C4 | UInt8 only |
| `Premultiplied_RGBA_To_RGBA` | 85 | `COLOR_mRGBA2RGBA` | C4 -> C4 | UInt8 only |

`CvtHelper` forward HSV/HLS/Lab/Luv allows native C3/C4 -> C3; reverse allows
C3 -> C3/C4. Its depth set is `Set<CV_8U, CV_32F>`. Public BGR/RGB names
deliberately require exactly C3, and explicitly pass destination channels 3.
Premultiplied wrappers use `Set<4>, Set<4>, Set<CV_8U>` in every tag.
All sources must be nonempty, 2-D. Geometry and depth are unchanged.
OpenCL requires a UMat destination and is unreachable for this Mat-only API.

Depth metadata now describes support, not transfer semantics:
`uint8_uint16_or_float32`, `uint8_or_float32`, `uint8_only`; Ada uses the
corresponding exhaustive `Color_Depth_Policy` instead of `Nonlinear_Color`.
Channel policy is also exhaustive. Existing validation is not weakened.

## FULL hue semantics: native asymmetry retained

Every pinned CPU `cvtBGRtoHSV` in `color_hsv.simd.hpp` initializes:

```cpp
int hrange = depth == CV_32F ? 360 : isFullRange ? 256 : 180;
```

This feeds `RGB2HSV_b/f` or `RGB2HLS_b/f`. Every reverse `cvtHSVtoBGR` uses:

```cpp
int hrange = depth == CV_32F ? 360 : isFullRange ? 255 : 180;
```

This feeds `HSV2RGB_b/f` or `HLS2RGB_b/f`. **Forward UInt8 FULL scale is 256,
reverse is 255**, intentionally asymmetric. Storage remains UInt8 0..255,
not a stored 256. Quantization plus this scale difference precludes a general
exact integer round-trip promise. No binding-side correction is applied.

Float32 uses **360 degrees irrespective of FULL**, in both directions and
both families; FULL and standard are numerically equivalent on the reviewed
portable paths. It does not change floating hue to byte-like 0..255.
Inputs are not normalized, clamped or sanitized by the binding.

## Linear-light Lab/Luv

In all tags, `color.cpp` groups L* selectors with ordinary Lab/Luv selectors
and passes `is_sRGB(code)`. `color.hpp::is_sRGB` returns true only for the
eight ordinary RGB/BGR Lab/Luv selectors; all eight L* codes return false.
RGB2Lab/RGB2Luv use linear rather than sRGB gamma tables (or bypass gamma
lookup); Lab2RGB/Luv2RGB omit sRGB inverse transfer encoding when false.
The nonlinear CIE mapping itself is unchanged; "linear" describes RGB light,
not a claim that the whole Lab/Luv transform is linear.

Float32 RGB normally uses 0..1; UInt8 uses native 0..255 encoding. Lab/Luv
component encoding is native for the selected depth (e.g. Float32 L* 0..100,
UInt8 encoded lightness 0..255). No manual gamma or component rescaling,
per-pixel range enforcement, or aliases to sRGB conversions are introduced.
Native table/interpolation/SIMD roundoff and byte quantization justify tolerant
round trips rather than cross-release bit-pattern assertions.

## Exact potential IPP reachability

The following table is identical for the public shapes in **4.1/4.10/5.0**.
"Yes" means an applicable native branch can invoke `CvtColorIPPLoop*` when
built/enabled; `IPP_DISABLE_*` and runtime IPP checks may remove it. A table
entry for a depth alone is insufficient: outer dispatch conditions matter.

| Selectors | UInt8 | Float32 | Relevant native condition |
| --- | --- | --- | --- |
| BGR -> HSV FULL | Yes | No | `depth == CV_8U && isFullRange`, C3 `!swapBlue`; RGB-HSV disable macro may remove it |
| RGB -> HSV FULL | **No** | No | HSV forward has no C3 `swapBlue` branch (C4 is not exposed) |
| HSV FULL -> BGR/RGB | Yes, both | No | C3 reverse covers both swap choices |
| BGR/RGB -> HLS FULL | Yes, both | No | C3 forward covers both swap choices |
| HLS FULL -> BGR/RGB | Yes, both | No | C3 reverse covers both swap choices |
| Linear BGR/RGB -> Lab | Yes, both | **No** | `!srgb && isLab && depth == CV_8U`; BGR function plus reorder for RGB |
| Lab -> Linear BGR/RGB | Yes, both | **No** | `!srgb && isLab && depth == CV_8U`; reverse BGR function plus reorder |
| Linear BGR/RGB -> Luv | Yes, both | **Yes, both** | `!srgb && !isLab`; `ippiRGBToLUVTab` has 8u/32f entries, both C3 swap choices |
| Luv -> Linear BGR/RGB | Yes, both | **Yes, both** | `!srgb && !isLab`; `ippiLUVToRGBTab` has 8u/32f entries, both C3 swap choices |
| RGBA -> premultiplied RGBA | Yes | Not supported | `ippiAlphaPremul_8u_AC4R` |
| premultiplied RGBA -> RGBA | **No** | Not supported | CALL_HAL then CPU dispatch, no IPP branch |

Standard HSV/HLS and ordinary sRGB Lab/Luv still bypass these IPP branches.
`color_may_use_ipp` enumerates applicable semantic selector constants rather
than relying on numeric ranges. Float32 HLS IPP table entries do **not** make
Float32 HLS reachable: the outer FULL IPP gate requires CV_8U.

## Alpha arithmetic and SIMD evolution

Every tag's `RGBA2mRGBA<uchar>` scalar tail is exactly:

```text
C' = (C * A + 128) / 255  for each of R, G, B
A' = A
```

Products and additions fit signed int (at most 65153). `mRGBA2RGBA<uchar>`:

```text
A == 0: C = 0
A != 0: C = saturate_cast<uchar>((Cpremul * 255 + A / 2) / A)
A' = A
```

Zero-alpha color is zero even for nonzero stored color. Components greater
than alpha are **accepted** and saturate. Forward/inverse loss at low alpha
is real: `(200,100,50,1)` becomes `(1,0,0,1)` then `(255,0,0,1)`.
Opaque pixels retain their colors. Formulas appear only as independent test
expectations, never production Ada algorithms.

4.1 SIMD uses fixed universal intrinsics (`v_uint8::nlanes`, vector operators)
and Lab also contains older SSE-specific paths. 4.10/5.0 use `VTraits::vlanes`
and named universal operations, supporting scalable SIMD where available.
Forward alpha vectors widen multiply, add 129, and perform the divide-255
shift identity, then select original alpha; scalar tails use the formula above.
Reverse vectors convert widened values, divide with half-alpha rounding,
truncate/pack with saturation and select zero at zero alpha. These structural
changes do not change the scalar contracts. HSV/HLS vector organization and
Lab/Luv table/interpolation code evolve; tolerances allow release/backend
roundoff. Tests use 257-column rows to exercise vector blocks and scalar tails.
5.0 adds hint plumbing elsewhere and explicit `CV_DEPTH_MAX` IPP table sizes;
neither changes this public channel/depth contract.

## HAL/vendor dispatch and narrowing

All six native dispatchers invoke `CALL_HAL` before their IPP/CPU paths.
HAL signatures have `size_t` byte steps and signed-int width/height.
Portable `hal_ni_cvt*` replacements return NOT_IMPLEMENTED, falling back to
native CPU implementation. Unknown external plugins are not modeled or
assigned speculative limits beyond the documented HAL contract.

- **Carotene (all tags):** replaces forward UInt8 HSV, including FULL,
  BGR/RGB (and native C4 variants not exposed). It does not replace HLS,
  reverse HSV, linear Lab/Luv, or alpha. Its HSV routines use hrange 256 for
  FULL, size_t pixel/row offsets, but **ptrdiff_t byte strides** after implicit
  HAL size_t conversion. Tegra scheduling repeats signed width*height.
  Guard actual source parent step and fresh C3 output step against PTRDIFF_MAX.
  Existing ordinary UInt8 HSV has the same stride hazard, so is covered too.
  Existing forward 565 retains its analogous Carotene guard.
- **FastCV (5.0):** `fastcv_hal_cvtBGRtoHSV` supports only C3 UInt8 RGB,
  FULL HSV, at most 640*480 pixels. Its **first** size check multiplies signed
  width*height, even before checking depth/mode. It then passes HAL size_t
  strides to `fcvColorRGB888ToHSV888u8` **uint32_t** stride arguments.
  This is not an int-stride backend. Inspecting the exact SDK selected by
  `FASTCV_COMMIT=9e8d42b6d7e769548d70b2e5674e263b056de8b4`, Linux aarch64
  package `fastcv_linux_aarch64_2025_07_09.tgz`, `inc/fastcv.h` confirms that
  signature. Guard source/output against UINT32_MAX for that reachable
  selector/depth/size combination. Width*3 stride checks widen to size_t.
  No HLS/Lab/Luv/alpha replacement is registered here. The binary vendor
  implementation is not treated as inspectable portable CPU source.
- **RISC-V RVV (5.0):** replaces both HSV/HLS directions and Lab/Luv,
  UInt8/Float32, with size_t row strides (Float32 divides by sizeof(float)).
  `color::invoke` computes signed `(width-1)*height` before double;
  `j*3` offsets and a linear-Luv scratch `vector<float>(width*3)` are signed.
  Pixel-product and C3 scalar-row guards cover them. No step-to-int or
  step-to-ptrdiff_t narrowing was found in these replacements.

No reviewed backend reads parent geometry/neighborhood for these per-pixel
conversions. Size_t row offsets/rows*step in CPU, RVV and Carotene address
Core-owned valid Mat storage; no additional signed rows*step conversion was
found. Bounded lane-count products are not whole-row dimensional narrowing.

## Shared signed scheduling product and safety boundary

All three `color.simd_helpers.hpp::CvtColorLoop` versions use:

```cpp
(width * height) / static_cast<double>(1<<16)
```

Both operands are signed int; the multiplication happens **before** floating
conversion. Every new conversion reaches that helper on portable fallback.
The same is true of **all existing exposed color selectors**: layout/Gray,
XYZ, YCrCb/YUV, standard HSV/HLS, ordinary Lab/Luv, and packed 565/555.
Consequently widened `uint64_t(cols) * rows <= INT_MAX` is checked once for
the **entire 0..85 table**, replacing the packed-only exception. This also
protects reachable IPP, Carotene and FastCV scheduling/size expressions and
RVV's smaller `(width-1)*height` scheduling product.

HSV/Lab/Luv CPU functors also compute signed `n *= 3`/`n*3` row bounds,
including Float32 RGB2HSV/HSV2RGB and older RGB2Lab/Lab2RGB. Guard
`uint64_t(cols) * 3 <= INT_MAX` for the UInt8/Float32-only color family,
including existing standard/sRGB members and all sixteen new C3 members.
Premultiplied loops increment pixel pointers and use bounded lane multiples;
no new whole-row `width*4` guard is needed for those CPU functors.

For each actually IPP-reachable selector/depth pair, source **actual parent
byte step** and fresh destination `cols * destination_channels * elemSize1`
must fit INT_MAX: `CvtColorIPPLoop_Invoker` narrows both size_t steps to int.
The output calculation uses widened arithmetic/division before native entry.
Non-IPP pairs are not subjected to this INT_MAX stride restriction.
Carotene and FastCV have the separate limits described above.

All retained guards carry concrete `ABI safety:` comments. Retained duplicated
layout checks (empty/2-D, exact channel count and supported depth) prevent
malformed raw Mat metadata from reaching pointer-only HAL implementations:
channel indexing, four-byte alpha accesses, ushort accesses, or interpreting
unsupported depth as float can mis-size reads/writes. They are not a second
friendly public policy layer. The public exact C3 policy does not expose
native C4 flexibility. There is no pixel-range or canonical-alpha validation
in the shim and no output postcondition restating OpenCV semantics.

## Regions, ownership and atomic publication

Core owns all Mat handles. The shim borrows Source read-only, passes its
logical rows/columns and actual parent stride directly, creates a **local
empty cv::Mat result**, and only moves it to Destination after full success.
Source Regions therefore behave like clones of their logical pixels without
an isolation clone. Outside parent pixels do not participate.
Same-object and distinct shared-header calls retain source storage during
native work. Old Destination Regions rebind to fresh result storage without
changing parents. Exception translation and all preflight failures leave an
existing Destination untouched; a subsequent valid raw call recovers.

## Verification

Baseline: 650 registered/executed/passed. Extended tests cover every selector,
known byte FULL hue (magenta exceeds standard range), reverse 0/128/254/255,
all Float32 standard/FULL directions and orders, both linear spaces/orders/
depths, black/white/mid-gray/asymmetric colors, transfer differences, scalar
alpha expectations across vector rows/tails, malformed alpha saturation,
Regions, publication, public rejection and malformed raw ABI recovery.
Huge arithmetic/stride boundaries are source-reviewed, not huge-allocated.
Strict Ada builds include -gnatwc; changed C++ uses warning-as-error switches.
There are 37 new focused tests: final registration/execution/pass count is
687/687/687, with zero failed assertions and zero unexpected errors.