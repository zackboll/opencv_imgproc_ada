# Portable phase correlation / Hanning source review

Reviewed exact upstream tags **4.1.0**, **4.10.0**, **5.0.0**. These are
source findings, not a claim that all three versions were executed locally.
Local behavioral validation uses OpenCV 4.10.0, ordinary CPU `cv::Mat`.

## Pinned sources

For each tag, inspected the following paths under
`https://github.com/opencv/opencv/blob/<tag>/`:

- `modules/imgproc/include/opencv2/imgproc.hpp`
- `modules/imgproc/src/phasecorr.cpp`
- `modules/core/src/dxt.cpp`
- `modules/core/src/copy.cpp`
- `modules/core/src/mathfuncs.cpp` (Hanning's terminal sqrt)

Direct phasecorr references:
[4.1.0](https://github.com/opencv/opencv/blob/4.1.0/modules/imgproc/src/phasecorr.cpp),
[4.10.0](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/phasecorr.cpp),
[5.0.0](https://github.com/opencv/opencv/blob/5.0.0/modules/imgproc/src/phasecorr.cpp).

All declare `Point2d phaseCorrelate(InputArray src1, InputArray src2,
InputArray window = noArray(), double* response = 0)` and
`void createHanningWindow(OutputArray dst, Size winSize, int type)`.
The iterative variant is declared only in the reviewed 5.0.0 header and
intentionally remains unbound. No divSpectrums or public DFT API is added.

## Algorithm, ownership, Regions

All three ordinary implementations pad to native optimal dimensions,
multiply an explicitly supplied window into both working images, perform
real forward DFT / conjugate spectrum multiplication / magnitude division /
inverse DFT, shift quadrants, locate a maximum and use a 5x5 weighted centroid.
Return is `center - centroid`; response is centroid energy divided by `M*N`.
There is no implicit window creation despite wording in the header narrative.

When dimensions are already optimal, `padded1 = src1`, `padded2 = src2`
are shallow assignments. Window multiplication writes that shared storage.
All three inputs are independently cloned before native execution, even
without a window. This protects original pixels, aliases, overlapping Regions,
and Window/source aliases. Packed clones also prevent copyMakeBorder's
non-isolated ROI expansion (`locateROI` / `adjustROI`) from seeing parent pixels.
Native assertions reject mismatched source or nonempty window types/sizes;
they remain native checks, not duplicated public semantic policy in the shim.

The controlled synthetic-image tests verify that moving Source_2 right/down
returns positive X/Y. Thus negating the result aligns Source_2 to Source_1.
No reinterpretation, input normalization, depth conversion or finiteness scan
is performed. No image-derived float-to-integer coordinate conversion was
found in the ordinary path: peak coordinates come from minMaxLoc.

## Material numerical differences

**Correction to the proposed 4.1/4.10 versus 5 split:** 4.10 already has
the absolute-magnitude behavior. In 4.1 magSpectrums, both Float32 and
Float64 paths square the special real entries:

- two-dimensional C1 first/last packed columns: `dataSrc[0]*dataSrc[0]`
  and the even-height `(rows-1)*stepSrc` entry;
- one-dimensional C1 DC and even-width Nyquist (`j1`) entries likewise square.

In **both 4.10 and 5.0**, those expressions use `std::abs`, with Float32
casts in that branch. Complex pairs continue to use sqrt(real² + imaginary²).
The binding delegates to the installed algorithm; response bit patterns and
even response values are not required to match releases. Native comments
explicitly allow normalization slightly above one due to rounding.

Hanning is sqrt of the full separable Hann product, not merely the product.
4.1 and 4.10 use scalar cosine coefficient loops (4.1 has `2.0f` in its
vertical coefficient expression; promotion still occurs with CV_PI).
5.0 adds universal-intrinsics vector cosine and vector product/store paths,
including scalable 64-bit lanes. All finish with `cv::sqrt(dst, dst)`.
Tests use symmetry, center/edge and separability tolerances, not exact bits.

## Signed-arithmetic / allocation preflight

All arithmetic in shim guards is widened before multiplication.

| Native expression/path | Boundary |
| --- | --- |
| getOptimalDFTSize table lookup | Reject M/N <= 0; lookup returns -1 at/above final table entry |
| response `M*N`; CPU IPP DFT `width*height` | M*N <= INT_MAX |
| weightedCentroid `peak.x/y + 2`, before clamping | M/N <= INT_MAX-1 |
| weightedCentroid `minr*src.cols` | Dominated by M*N bound |
| mag/divSpectrums `cols*cn`; 1-D `cols+rows-1` | C1 packed CCS from ordinary forward DFT; C2 column scratch conservatively bounded by complex-byte guard; flattened dimension <= max(M,N) |
| CopyFrom2Columns / CopyTo2Columns `len*2`, `len*4` | max(M,N)*2*scalar_bytes <= INT_MAX (dominates *4) |
| OcvDftImpl scratch `len*complex_elem_size`; OcvDftBasicImpl wave `opt.n*complex_elem_size` | Same complex-byte bound (4.1, 4.10, 5.0) |
| DFT permutation / real expansion indices (`2*k`, `n+1`) | Dominated by complex-byte bound |
| padding `M-rows`, `N-cols`; copyMakeBorder dimension additions | Optimal positive dimensions >= source; source mismatch assertions precede padding |
| copyMakeConstBorder_8u `dstroi.width*cn`, `i*cn+j` (cn is bytes) | Complex-byte bound dominates padded scalar row bytes |
| DFT/Mat row addressing, scratch allocation | M*N*2*scalar_bytes fits size_t; packed steps, not original parent strides |
| fftShift half/odd Rect coordinates and extents | Half+odd and origin+extent stay within M/N; dimensions bounded as above |
| Hanning AutoBuffer<double>(cols) | cols*sizeof(double) fits size_t |
| Hanning output allocation and ptr(row) | rows*cols*scalar_bytes and row bytes fit size_t |
| sqrt -> pow continuous NAryMatIterator `int len = (int)(it.size*cn)` | Hanning rows*cols <= INT_MAX; C1 |

CPU Mat outputs exclude UMat/OpenCL FFT plans. DFT row/column steps in the
reviewed portable implementation are size_t; IPP wrappers narrow packed
steps to int, covered by the byte-width bound. Vendor HAL/IPP internals remain
trusted external implementations; their opaque returned buffer sizes are
not reimplemented here. No arbitrary small dimension cap is introduced.

Hanning dimensions/selectors arrive as int32_t. Invalid width/height are
rejected by native CV_Assert before allocation, preserving the OpenCV-error
path and previous output. Selector validation belongs to C ABI decoding.
Fresh local output is moved into the borrowed Core header only on success.
Phase scalars likewise remain unchanged until all native work succeeds.

### Validation-boundary review

Retained duplicated public layout conditions: nonempty 2-D phase sources
(and nonempty supplied windows must be 2-D). These prevent rows/cols padding
before dimensionality checks and empty peak/data access in weightedCentroid.
They have explicit ABI-safety comments. No depth, channel, matching geometry,
or matching type policy is duplicated; native assertions handle raw callers.
Hanning width/height CV_Assert is retained before converting to unsigned byte
products: negative-to-unsigned conversion could wrap the preflight products.
It uses native assertion translation and has an explicit ABI-safety comment.