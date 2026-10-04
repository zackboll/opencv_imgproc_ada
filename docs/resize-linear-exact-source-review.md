# Portable bit-exact linear Resize: exact-tag source review

## Scope and evidence

Reviewed upstream **4.1.0**, **4.10.0**, and **5.0.0**, not a moving branch:

| Tag | Commit |
| --- | --- |
| 4.1.0 | `371bba8f54560b374fbcd47e7e02f015ac4969ad` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |

For each tag the authoritative sources are:

- `modules/imgproc/include/opencv2/imgproc.hpp` (enum and Resize declaration);
- `modules/imgproc/src/resize.cpp` (`interpolationLinear`,
  `resize_bitExactInvoker`, `resize_bitExact`, `hal::resize`, `cv::resize`);
- `modules/imgproc/src/fixedpoint.inl.hpp` (coefficient and result rounding);
- `modules/imgproc/include/opencv2/imgproc/hal/hal.hpp` (size_t stride ABI);
- `modules/imgproc/src/hal_replacement.hpp` (default and custom HAL hooks);
- `modules/imgproc/src/precomp.hpp` (`ippiGetInterpolation`).

Exact-tag browsing roots:
[4.1.0](https://github.com/opencv/opencv/tree/4.1.0),
[4.10.0](https://github.com/opencv/opencv/tree/4.10.0),
[5.0.0](https://github.com/opencv/opencv/tree/5.0.0).

Key `resize.cpp` locations (1-based upstream lines):

| Finding | 4.1.0 | 4.10.0 | 5.0.0 |
| --- | --- | --- | --- |
| interpolationLinear | 732 | 733 | 790 |
| invoker / linebuf | 774 / 791 | 775 / 792 | 832 / 849 |
| coefficient buffer | 870 | 871 | 928 |
| signed scheduling W*H | 890 | 891 | 948 |
| CALL_HAL before portable tables | 3356 | 3784 | 3849 |
| exact branch / Area routing | 3492 | 3920 | 3985 |
| float fallback / OpenCL | 3733 / 3736 | 4167 / 4170 | 4232 / 4235 |

Local runtime verification uses the installed **OpenCV 4.10.0** on Linux.
The final production shim is also syntax-checked against all three exact
public header sets. The generated enabled-module header is build metadata,
not a replacement for any exact-tag core/imgproc declaration. These checks
establish source compatibility only: they do **not** claim execution of
4.1.0 or 5.0.0, RVV hardware, or every vendor implementation.

## Public selectors, types and semantics

All three headers declare `INTER_LINEAR_EXACT = 5`. 4.1.0 does **not** declare
`INTER_NEAREST_EXACT`; 4.10.0 and 5.0.0 do. The binding appends only
`Linear_Exact` to `Interpolation_Method`, leaving existing literal positions
unchanged. Private selectors remain 0 nearest, 1 linear, 2 cubic, 3 area,
4 Lanczos4, with 5 exact linear appended. These are semantic ABI selectors,
not public native flag encodings. Selector 6 and malformed selectors reject.

`to_opencv_resize_interpolation` alone accepts selector 5. The generic native
mapper retains its existing set. Ada's Resize mapper is likewise
operation-specific. All Remap overloads and the restricted warp APIs reject
the appended literal; fixed-map conversion takes a nearest-only Boolean,
not this enum. Native Remap does not implement exact interpolation, so no
exact Remap or warp variant is introduced. Neither nearest-exact,
WARP_RELATIVE_MAP (absent in 4.1), nor AlgorithmHint is added.

`linear_exact_tab` contains implementations for CV_8U, CV_8S, CV_16U,
CV_16S, CV_32S, and null floating entries in **all three** tags. The existing
public Resize depth domain is not broadened: exact supports **UInt8,
UInt16, Int16**. `cv::resize` explicitly rewrites exact to ordinary Linear
for CV_32F/CV_64F before dispatch. Thick Ada deliberately rejects those two
requests with `OpenCV_Error` before borrowing Destination, even at identical
geometry. Ordinary floating Linear is unchanged. The raw ABI preserves the
native-safe float fallback; it does not duplicate this semantic policy.

The channel switch specializes C1..C4 and uses `hlineResize` for every other
channel count. No new C1..C4 restriction is justified. Result depth and
channel count remain those of Source; the public tests include C5/C6 using
Core Merge/Split rather than a competing access abstraction.

### Fixed-point numerical meaning and independent fixtures

`interpolationLinear::getCoeffs` computes the half-pixel coordinate
`scale*(destination_index+0.5)-0.5` using `softdouble`; interior second
coefficients are rounded to fixed point, with first coefficient `one-second`.
Out-of-image samples replicate the edge. `fixedtype` uses unsigned Q8
(2-byte `ufixedpoint16`) for UInt8, unsigned Q16 (4-byte
`ufixedpoint32`) for UInt16, signed Q16 (4-byte `fixedpoint32`) for Int16.
Products accumulate into wider fixed-point types; final conversion adds a
half unit before shifting and saturating. Signed half-way values round
toward positive infinity, not by unsigned reinterpretation. This is intended
deterministic integer bilinear interpolation, **not** exact real arithmetic,
lossless resizing, nearest neighbor, or necessarily ordinary Linear.

`tests/resize_exact_reference_test.cpp` independently derives the 2x3 -> 3x5
fixture from Q8/Q16 coefficients. The x fractions are 0, 2/5, 0, 3/5, 0;
the middle output row has y fraction 1/2. Expected data is computed with
integer arithmetic, never by a second OpenCV call. The AUnit suite pins all
15 values for each depth. UInt8 source `[[3,71,199],[22,117,241]]` gives exact
170 at zero-based (1,3), versus ordinary Linear 169 locally. UInt16 uses
101, 12003, 60001, 903, 33007, 65003; Int16 uses -301, -71, 199, -22, 117,
1241, testing rounding across zero. These are not symmetric extreme fixtures.

SIMD differs by version: 4.1 uses CV_SIMD guards and older vector APIs;
4.10/5 use CV_SIMD or CV_SIMD_SCALABLE and VTraits. The fixed-point model,
depth table and scalar/generic channel semantics are retained. The binding
calls OpenCV, not a reimplementation, and does not select or disable SIMD.

## Copy, Area, Region, and strides

After Mat destination creation, `cv::resize` tests `dsize == ssize`, calls
`src.copyTo(dst)`, and returns **before HAL/interpolation processing** in all
tags. Same-size supported integer exact requests therefore copy content.
No exact-path product guard is applied to a path which is only a copy.

In the portable HAL fallback, exact with integer scales 2 and 2 redirects
to fast Area **only when channels != 2**. The upstream comment explicitly
states that two-channel Area is not bit-exact. This routing is preserved.
C1 tests compare the native redirect with Area; C2 tests pin the average
0.5 as exact 1, versus Area's 0 on the local native path. A HAL which consumes
exact earlier need not execute this portable optimization.

`resize_bitExactInvoker` stores `size_t src_step, dst_step`; row addressing
uses `src+i*src_step` and `dst+dst_step*dy`, with no narrowing before use.
There is no general exact-path IPP/int stride restriction. A strided Region
is its own logical source: x coefficients use its width, edge replication
uses its first/last logical pixel, row reads use its actual parent stride,
and no `locateROI` or external-border expansion is performed. Tests use a
conspicuously different parent and compare Region with Region.Clone.

**Exception: native 2x Area redirect.** `resizeAreaFast_Invoker` narrows
`src.step` to int for VecOp row access. The Area offset table also casts
`src_step/elemSize1 + sx*cn` to int (sx=0 or 1). Its signed source width
and destination width are multiplied by channels. Those actual reachable
conditions are preflighted only for 2x/2x, non-C2. The Region is not packed or
otherwise changed merely to avoid these checks.

## Concrete native arithmetic and allocation review

`cpp/resize_exact_layout_fits.hpp` uses uint64_t and division before
multiplication; its allocation-free static_assert test exercises signed and
synthetic address-limit boundaries. Each guard names its protected native
expression with an `ABI safety:` comment.

For non-copy integer exact execution:

- source W*cn <= INT_MAX protects signed `cn*ofst[i]` in generic/specialized
  horizontal addressing and source W*cn in Area;
- 2*output W*cn <= INT_MAX protects
  `AutoBuffer<FT> linebuf(interp_y_len*dst_width*cn)` with interp_y_len=2,
  repeated signed W*cn arguments, line offsets, and signed 2*W coefficient
  offsets (the separate W*cn and 2*W bounds are implied, not duplicated);
- 2*output H <= INT_MAX protects 2*dy coefficient indexing, including the
  invoker's `dy*2-evalbuf_start+2+i` expression;
- output W*H <= INT_MAX protects the product evaluated **before** conversion
  in `parallel_for_(..., dst_width*dst_height/(double)(1<<16))`;
- source row extent `(source_H-1)*step + source_W*cn*sizeof(ET)` and packed
  destination H*W*cn*sizeof(ET) must fit the address limit;
- coefficient buffer bytes are `(W+H)*(sizeof(int)+2*sizeof(FT))`.
  W*sizeof(int) and H*sizeof(int) are size_t-safe multiplications, but
  `W*interp_x.len` and `H*interp_y.len` are evaluated as signed int before
  the following sizeof factor. The total sum still needs size_t protection;
- per-worker bytes are 2*W*cn*sizeof(FT). This multiplication and the typed
  coefficient/line-buffer pointer spans must fit the smaller of SIZE_MAX
  and PTRDIFF_MAX. The helper protects the actual FT sizes (2/4 bytes for
  public depths; 4/8 for other raw supported integer depths).

The signed source-y terms are also reviewed: interior iy <= source_H-2,
so iy+2 and last_eval+2 do not exceed source_H. Coefficient offsets and line
ring indices have length 2. No additional arbitrary image-size ceiling or
blanket source stride cap is imposed. Allocation failure is not relied upon
to detect signed overflow. Same-size copy and raw floating fallback do not
enter this integer exact preflight.

## HAL/vendor reachability (not ordinary Linear assumptions)

All three `hal::resize` functions invoke **CALL_HAL first**, before IPP and
the portable exact branch. Default `hal_ni_resize` returns NOT_IMPLEMENTED;
`custom_hal.hpp` can replace it. A registered external HAL can therefore
consume exact first; the binding cannot promise that every build executes
the portable `resize_bitExact` routine.

- **4.1/4.10 Carotene:** `3rdparty/carotene/hal/tegra_hal.hpp`,
  `TEGRA_RESIZE`, accepts only CV_HAL_INTER_LINEAR or AREA; exact is neither
  and returns NOT_IMPLEMENTED. 5.0 moves this under `hal/carotene`; it has
  the same selector limitation. Its ordinary Linear behavior is irrelevant.
- **4.x OpenVX:** `3rdparty/openvx/hal/openvx_hal.hpp` has the resize override
  commented out. It does not consume exact. The 5.0 in-tree HAL layout has
  no OpenVX resize replacement.
- **4.1/4.10 RVV/FastCV:** no in-tree cv_hal_resize override in these exact
  trees. Ordinary universal SIMD in portable resize is distinct from a HAL.
- **5.0 RVV:** `hal/riscv-rvv/include/imgproc.hpp` registers cv_hal_resize;
  `hal/riscv-rvv/src/imgproc/resize.cpp` lines 989..1000 accepts exact.
  `resizeLinear` lines 771..803 handles exact **UInt8 C1..C4**, unless source
  width*element-bytes exceeds ushort indexing capacity, then declines.
  It uses x/y Q8 coefficients and RNU widening/vector rounding in
  `resizeLinearExact` (318..440), with size_t row steps. It computes
  coefficients using double and remainder rather than portable softdouble.
  UInt16/Int16 exact and >4 channels fall through to portable processing.
  This is case **B**, not an unconditional portable-path case A. Source
  W*cn and destination W*cn guards also cover its signed indexing products.
- **5.0 FastCV, IPP HAL, KleidiCV, ArmPL, ndsrvp:** reviewed their in-tree HAL
  directories; none registers cv_hal_resize. FastCV's diagnostic selector
  name for value 5 does not establish a resize implementation.
- **IPP resize.cpp path, all tags:** `ippiGetInterpolation` maps nearest,
  linear, cubic, Lanczos4, Area, then returns -1 for exact. `ipp_resize`
  immediately returns false before constructing IW images or using strides.
  The later portable 2x Area redirect does not re-enter IPP dispatch. Thus
  ordinary Linear's IPP narrowing/approximation is not an exact-path bound.

No backend is overridden or forced by the binding. Unknown third-party HAL
implementations remain the OpenCV build's responsibility, not a claim of
vendor runtime verification.

## OpenCL

All tags use the exact condition
`_src.dims() <= 2 && _dst.isUMat() && _src.cols() > 10 && _src.rows() > 10`
for CV_OCL_RUN. The module bridge supplies a native **Mat** destination, so
`_dst.isUMat()` is false and OpenCL resize is unreachable through this API.
No UMat support is added. This remains true for raw float fallback as well.

## Validation ownership

Ada owns the integer-only public exact contract and unsupported-operation
policy. The shim validates borrowed handles, selector representation and
concrete native arithmetic/address safety; it does not duplicate the float
rejection or channel-domain policy. **No public semantic validation is
duplicated in the C++ shim.** The semantic-looking 2x/non-C2 condition only
selects guards for native Area's narrowed stride/offsets, not a public mode
restriction. Comments identify these actual ABI/memory failure modes.