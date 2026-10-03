#ifndef OPENCV_IMGPROC_BAYER_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_BAYER_LAYOUT_FITS_HPP

#include <climits>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace opencv_imgproc_detail {

constexpr bool bayer_source_span_fits(uint64_t rows, uint64_t row_bytes,
                                      uint64_t step, uint64_t address_limit)
{
    // ABI safety: snapshot row copies form data+(rows-1)*step and access
    // row_bytes there. Reject wrapped/unaddressable parent-stride spans.
    return rows > 0 && row_bytes > 0 && step >= row_bytes &&
           row_bytes <= address_limit &&
           (rows == 1 || step <= (address_limit - row_bytes) / (rows - 1));
}

constexpr bool bayer_vng_layout_fits(uint64_t rows, uint64_t cols,
                                     uint64_t address_limit)
{
    const uint64_t limit = INT_MAX;
    // ABI safety: OpenCV 5 copyMakeBorder adds four to each signed size;
    // N7=N*7, bufstep=N7*7, AutoBuffer<ushort>(bufstep*3): N*147.
    if (cols > limit - 4 || rows > limit - 4)
        return false;
    const uint64_t n = cols + 4, h = rows + 4;
    if (n > limit / 147)
        return false;
    // ABI safety: largest padded signed row term (y+dy)*bstep is
    // (h-2)*n; neighbor expressions include bstep*2+2.
    if (h - 2 > limit / n)
        return false;
    // ABI safety: padded Mat byte addressing and ushort buffer bytes.
    return h <= address_limit / n && n * 147 <= address_limit / 2;
}

// Pure pre-allocation arithmetic, also exercised without allocating huge Mats.
constexpr bool bayer_layout_fits(uint64_t rows, uint64_t cols,
                                 uint64_t channels, uint64_t bytes,
                                 bool vng, bool edge_aware,
                                 uint64_t address_limit =
                                     std::numeric_limits<std::ptrdiff_t>::max())
{
    const uint64_t limit = INT_MAX;
    if (rows == 0 || cols == 0 || rows > limit || cols > limit ||
        (channels != 1 && channels != 3 && channels != 4) ||
        (bytes != 1 && bytes != 2))
        return false;
    // ABI safety: int(dst.step/sizeof(T)), width*dcn and EA size.width*=3.
    if (cols > limit / channels)
        return false;
    const uint64_t stride = cols * channels;
    // ABI safety: bilinear/Gray i+(height-1)*dst_step reaches
    // rows*stride-1. EA row products use size_t, not signed int.
    if (!edge_aware && rows > (limit + 1) / stride)
        return false;
    // ABI safety: Mat pointer offsets and allocator byte counts must fit
    // ptrdiff_t (also sufficient for size_t on supported 32/64-bit targets).
    if (stride > address_limit / bytes ||
        rows > address_limit / (stride * bytes))
        return false;
    // ABI safety: invokers form bayer+cols-2 before testing width<=0.
    // With cols=1 and rows>2 this forms a pointer before the snapshot.
    if (!edge_aware && cols == 1 && rows > 2)
        return false;
    return !vng || rows < 8 || cols < 8 ||
           bayer_vng_layout_fits(rows, cols, address_limit);
}

} // namespace opencv_imgproc_detail
#endif