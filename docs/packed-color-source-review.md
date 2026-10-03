# Packed color source review

## Scope and pinned evidence

Source reviewed at exact OpenCV tags **4.1.0**, **4.10.0**, **5.0.0**.
Runtime validation in this task uses installed OpenCV **4.10.0** only; source
review is not a claim of execution on 4.1.0 or 5.0.0.

For each tag the authoritative files inspected are:

- `modules/imgproc/include/opencv2/imgproc.hpp` (`ColorConversionCodes`);
- `modules/imgproc/src/color.cpp` (`cvtColor` CPU/OpenCL dispatch);
- `modules/imgproc/src/color_rgb.dispatch.cpp` (wrappers, HAL and IPP);
- `modules/imgproc/src/color_rgb.simd.hpp` (four packed functors);
- `modules/imgproc/src/color.simd_helpers.hpp` (`CvtHelper`, `CvtColorLoop`,
  fixed-point constants);
- `modules/imgproc/include/opencv2/imgproc/hal/hal.hpp` (HAL declarations);
- `modules/imgproc/src/hal_replacement.hpp` (portable HAL replacement stubs).

Exact-tag source roots (append the paths above):

- <https://github.com/opencv/opencv/tree/4.1.0>
- <https://github.com/opencv/opencv/tree/4.10.0>
- <https://github.com/opencv/opencv/tree/5.0.0>

Vendor evidence: 4.1/4.10 `3rdparty/carotene/hal/tegra_hal.hpp` and
`3rdparty/carotene/src/colorconvert.cpp`; 5.0 `hal/carotene/hal/tegra_hal.hpp`
and `hal/carotene/src/colorconvert.cpp`. Also inspected 5.0
`hal/fastcv/include/fastcv_hal_imgproc.hpp` and
`hal/fastcv/src/fastcv_hal_imgproc.cpp`: no packed color replacement.

## Availability and allocation

All twenty declarations exist in all three pinned headers:

| Family | Packing codes | Expansion codes | Gray codes |
| --- | --- | --- | --- |
| 565 | `COLOR_BGR2BGR565`, `COLOR_RGB2BGR565`, `COLOR_BGRA2BGR565`, `COLOR_RGBA2BGR565` | `COLOR_BGR5652BGR`, `COLOR_BGR5652RGB`, `COLOR_BGR5652BGRA`, `COLOR_BGR5652RGBA` | `COLOR_GRAY2BGR565`, `COLOR_BGR5652GRAY` |
| 555 | `COLOR_BGR2BGR555`, `COLOR_RGB2BGR555`, `COLOR_BGRA2BGR555`, `COLOR_RGBA2BGR555` | `COLOR_BGR5552BGR`, `COLOR_BGR5552RGB`, `COLOR_BGR5552BGRA`, `COLOR_BGR5552RGBA` | `COLOR_GRAY2BGR555`, `COLOR_BGR5552GRAY` |

Their native enum integers are 12..31, but the binding deliberately uses its
own appended semantic selectors 48..67; existing 0..47 remain unchanged.

The four wrappers instantiate these `CvtHelper` policies in every version:

| Wrapper | Source channels | Destination channels | Depth |
| --- | --- | --- | --- |
| `cvtColorBGR25x5` | `Set<3,4>` | `Set<2>` | `Set<CV_8U>` |
| `cvtColor5x52BGR` | `Set<2>` | `Set<3,4>` | `Set<CV_8U>` |
| `cvtColorGray25x5` | `Set<1>` | `Set<2>` | `Set<CV_8U>` |
| `cvtColor5x52Gray` | `Set<2>` | `Set<1>` | `Set<CV_8U>` |

Ada requires the exact C3/C4 source indicated by the selector, rather than
exposing native wrapper flexibility. The table specifies C1/C2/C3/C4 output
explicitly and passes `dcn` to `cvtColor`; packing wrappers themselves use 2.
`CvtHelper` checks channels/depth, gets the source Mat, uses size policy NONE,
and calls `_dst.create(dstSz, CV_MAKETYPE(depth,dcn))`. Geometry is unchanged.
The shim supplies a local empty Mat, so native same-object copy logic is not
triggered; only after conversion succeeds does it move into Destination.
OpenCL is gated on UMat destination, unreachable for this Mat-only binding.
OpenCV 5 adds hint plumbing elsewhere; these four packed wrappers are unchanged.

## Exact scalar formulas and representation

`RGB2RGB5x5` uses `bidx = swapBlue ? 2 : 0`, reads blue from `src[bidx]`,
red from `src[bidx^2]`, and alpha from C4 only (otherwise zero):

```text
565: (b >> 3) | ((g & ~3) << 3) | ((r & ~7) << 8)
555: (b >> 3) | ((g & ~7) << 2) | ((r & ~7) << 7)
     | (a ? 0x8000 : 0)
```

Thus 565 fields are B 0..4, G 5..10, R 11..15; 555 fields are B 0..4,
G 5..9, R 10..14, alpha flag 15. RGB/RGBA changes channel interpretation,
not the packed word format. Packing truncates, never rounds.

`RGB5x52RGB` reads an unsigned native `ushort`:

```text
b = (uchar)(t << 3)
565: g = (uchar)((t >> 3) & ~3), r = (uchar)((t >> 8) & ~7), a = 255
555: g = (uchar)((t >> 2) & ~7), r = (uchar)((t >> 7) & ~7)
     a = (uchar)(((t & 0x8000) >> 15) * 255)
```

No low-bit replication: B/R maxima 248; green 252 (565) or 248 (555).
565 ignores input alpha. 555 nonzero alpha becomes a boolean flag, not
quantized 8-bit alpha. C3 packing leaves flag clear, hence C4 expansion alpha 0.

`Gray2RGB5x5` computes `t3 = t >> 3`:

```text
565: t3 | ((t & ~3) << 3) | (t3 << 11)
555: t3 | (t3 << 5) | (t3 << 10)
```

Gray-to-555 also leaves bit 15 clear. `RGB5x52Gray` first expands B/G/R
with masks F8/FC as above, then uses
`CV_DESCALE(b*BY15 + g*GY15 + r*RY15, gray_shift)`.
All tags use BY15=3735, GY15=19235, RY15=9798, gray_shift=15, i.e.
`(3735*B + 19235*G + 9798*R + 16384) >> 15`. Alpha is ignored.
White Gray round trips to 250 via 565 and 248 via 555.

CPU scalar writes/reads `ushort*`; universal SIMD uses native ushort stores.
The public Mat remains **CV_8UC2**, two bytes of one host-native 16-bit word.
This is not a little-endian/network/file serialization contract. Test-only
unchecked conversion obtains expected native bytes without hard-coding order.

## SIMD, HAL and IPP

4.1 uses `CV_SIMD`, fixed lane counts and operator-style intrinsics.
4.10/5.0 use `CV_SIMD || CV_SIMD_SCALABLE`, `VTraits::vlanes()` and functional
intrinsics. The four scalar fallbacks are semantically identical. SIMD masks,
shifts, alpha nonzero comparisons and fixed-point Gray dot products implement
the same integer formulas; no portable CPU semantic difference was found.
Tests use 257-pixel rows to cover vector blocks and scalar tails.

All four `hal::cvt*5x5` dispatchers first invoke `CALL_HAL`, then CPU dispatch.
**None has an IPP branch**, direct or `CvtColorIPPLoop_Invoker`. The shim now
uses explicit selector cases for IPP reachability rather than numeric ranges.
Portable `hal_ni_*5x5` replacements return NOT_IMPLEMENTED, delegating to CPU.

Carotene replaces only BGR/RGB/BGRA/RGBA-to-565 (`greenBits == 6`). Its
`rgb[x]2[bgr/rgb]565` loops use size_t indices/offsets, ptrdiff_t strides,
ignore alpha and use equivalent scalar ushort packing. NEON interleaves
explicit low/high bytes, consistent on supported little-endian ARM targets;
this does not justify a public serialized byte-order promise. No 555,
packed expansion or packed Gray Carotene replacement is selected.
Unknown third-party HAL plugins are outside this pinned implementation audit.

## Signed arithmetic and ABI safety

The shim retains layout preflight (nonempty, 2-D, matching channels, allowed
depth) for malformed raw callers. Concrete risk: raw HAL helpers receive only
data/strides/counts, not Mat metadata; functors index channel offsets and read
or write native ushort words. Wrong layout can cause mis-sized raw accesses.
This deliberate duplicate of Ada validation is documented with `ABI safety:`.

New packed guards, computed in uint64_t before native entry:

1. `cols * rows <= INT_MAX`: every portable `CvtColorLoop` computes signed
   `width * height` before division by double; Carotene's packing scheduler
   repeats this expression. Overflow is undefined even when used only to
   choose parallel stripes.
2. For ordinary-to-565 only: actual source `step[0]` and fresh output
   `cols * 2` must fit `ptrdiff_t`. Carotene implicitly converts HAL size_t
   strides to ptrdiff_t before `getRowPtr` addresses rows. No INT_MAX stride
   restriction is added: CPU row steps remain size_t, Carotene offsets size_t.

Packed scalar loops advance pointers, not signed `width * channels` offsets.
SIMD `vsize*scn`/`vsize*dcn` involve bounded native lane counts (channels <=4);
`vsize*sizeof(ushort)` is size_t. Loop increments stay <= width. No packed
IPP row-byte cast, full-row signed channel product or loop-count narrowing
was found. Color shifts and luminance accumulators fit int; native ushort
narrowing is intentional bit packing, not loss of unvalidated dimensions.

Source Region data, logical width/height and actual parent stride are passed
directly; no parent geometry lookup or neighborhood access occurs. No clone
is necessary. Local-result publication preserves old Destination on failures,
including raw selector 68, other invalid selectors and malformed depths.
Same-variable conversion retains source storage until native work finishes;
shared headers and old Destination Regions rebind without parent mutation.

## Verification coverage

Baseline 619; 31 focused packed tests bring registration to 650. Every new
selector has an independently computed native-word or expansion expectation,
plus metadata and source-preservation checks. Negative tests traverse all
non-UInt8 Core depths and wrong C1/C2/C3/C4 layouts for all twenty selectors,
empty/ND sources, raw rejection and recovery. Separate cases cover Regions,
same-object/shared-header/Region-destination publication and alpha/Gray
round trips. Huge allocation boundaries are reviewed, not runtime-allocated.