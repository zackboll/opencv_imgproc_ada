# Pinned image-accumulation review

Reviewed exact OpenCV tags **4.1.0**, **4.10.0**, and **5.0.0**, not a moving
branch. For each tag the authoritative files are:

- `modules/imgproc/include/opencv2/imgproc.hpp`
- `modules/imgproc/src/accum.cpp`
- `modules/imgproc/src/accum.simd.hpp` (CPU dispatch declarations, SIMD and
  scalar kernels used by the four tables)
- `modules/core/src/matrix_iterator.cpp` (`NAryMatIterator::init`)

Source links (substitute any of the three tags and paths above):
<https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/accum.cpp>,
<https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/accum.cpp>,
<https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/accum.cpp>.

## Documented contract versus implementation

Independently checked `getAccTabIdx` in **each** tag. All have exactly:

| Source | Destination | Index |
| --- | --- | --- |
| CV_8U | CV_32F | 0 |
| CV_8U | CV_64F | 1 |
| CV_16U | CV_32F | 2 |
| CV_16U | CV_64F | 3 |
| CV_32F | CV_32F | 4 |
| CV_32F | CV_64F | 5 |
| CV_64F | CV_64F | 6 |

Everything else returns -1; **CV_64F -> CV_32F is absent**. The four tables
(`accTab`, `accSqrTab`, `accProdTab`, `accWTab`) all use these same seven
handlers. OpenCV 5 explicitly sizes the tables with `CV_DEPTH_MAX`.

All three headers document arbitrary positive channel counts and
CV_8UC(n)/CV_16UC(n)/CV_32FC(n)/CV_64FC(n) sources for plain `accumulate`.
The Ada contract excludes the unsupported narrowing pair despite the broad
destination wording. All three headers document only 1/3-channel 8-bit or
32-bit floating sources for square, product and weighted accumulation;
destinations are matching-channel 32/64-bit floating. Ada deliberately does
**not** expose the extra UInt16/Float64/arbitrary-channel handlers for those
three operations. Product requires identical source type and size.

The native signatures are stable: InputArray source(s), InputOutputArray
destination, optional InputArray mask = noArray(); weighted adds double alpha.
Mask assertions in 4.1/4.10 require CV_8U (C1); 5.0 additionally accepts
CV_Bool. Ada exposes only the common UInt8 C1 mask. A zero mask sample skips
all channels; every nonzero value enables the pixel. No whole-image finite
scan or saturation is introduced. Weighted alpha is converted to accumulator
precision in scalar kernels; IPP uses Ipp32f alpha. Bitwise reproducibility
between accelerated and scalar floating arithmetic is not promised.

## Iterator and CPU integer arithmetic

The four functions create a NAryMatIterator over sources, destination and
mask; `int len = (int)it.size` feeds the dispatch handler. Iterator size is
**pixels, not channel scalars or bytes**. For supported 2-D layouts it is
columns per strided row, or rows*columns when the nonempty arrays can be
collapsed into a continuous plane. The iterator's own int64 flattening
check prevents a plane exceeding int, but kernels then evaluate `len *= cn`,
`int size = len * cn`, `i * cn`, and SIMD `x * cn` / `(x + step) * cn` using
signed int. Reviewed these expressions in each pinned accum.simd.hpp.

The shim conservatively bounds each nonempty input's total pixels and
total channel scalars by INT_MAX before native entry. This bounds every
possible 2-D iterator plane and channel index, including masked C3 SIMD
deinterleaving. Byte bounds below also bound the packed clone's row and total
size before allocation. These are layout safety limits, not pixel saturation.

## IPP / OpenCL / HAL / OpenVX

All tags have IPP helpers for the four operations. Eligible functions use
Float32 destinations, sources UInt8/UInt16/Float32, and masked handlers only
for C1. Unmasked channels are flattened with `size.width *= scn`.
They initially cast source/destination/mask `step` to int (both sources for
product). When all inputs are continuous, they assign
`total() * elemSize()` to signed strides, `total()` to width, and height=1.
The shim bounds **all** nonempty strides and total byte counts by INT_MAX,
including Base before cloning. Consequently packed working stride, flattened
width*channels, source2 and mask conversions are all safe regardless of
which eligible backend is installed. This is conservative for CPU-only or
Float64 paths but avoids dependence on build-time accelerator configuration.
No global/thread optimization state is toggled. IPP is allowed to execute.

OpenCL requires a UMat destination. The shim uses Mat, so it cannot enter that
branch. There is no separate `CALL_HAL` accumulation branch in these three
accum.cpp files; the HAL intrinsics include supplies CPU SIMD primitives.

**Both 4.1 and 4.10** retain OpenVX add/square/weighted paths (not product).
Their `skipSmallImages<VX_KERNEL_ACCUMULATE>` computes `w*h` in signed int
*before* the type gate. The pixel-total bound protects this even though
public floating accumulators are later declined. OpenVX requires UInt8 C1
sources and Int16 C1 destinations for add/square, UInt8 C1 destinations for
weighted, with no mask. None of the public contracts can execute these
integer/saturating paths. **5.0 removes OpenVX accumulation and legacy C
cvAcc/cvSquareAcc/cvMultiplyAcc/cvRunningAvg wrappers**, while retaining the
four native C++ functions. No backend disable or algorithm substitution is
needed for the public portable floating contract.

## Validation ownership and publication

Ada owns nonempty/2-D/geometry/depth/channel/product/mask/finite-weight policy.
C++ owns selectors, required handle resolution and native layout arithmetic
bounds. The duplicated 2-D restriction is annotated `ABI safety:` because
the preflight accesses 2-D rows/cols/step and protects the OpenVX width*height
probe. No source/destination depth or channel policy, mask contract, or weight
range/finiteness policy is duplicated. Raw semantic errors are normally
contained OpenCV assertion failures; raw nonfinite weights remain native
floating arithmetic, not unsafe integer conversion.

Base is cloned into a local continuous Mat, every native update targets that
clone, and output is rebound with move assignment only after success. No
inputs or caller result storage are modified on failure. Output handles are
borrowed Core headers, not newly owned shim wrappers. Logical Regions remain
bounded by their headers; no neighborhood or parent pixels are accessed.
Input aliases (including shifted overlaps) cannot overlap the working clone.