#ifndef OPENCV_IMGPROC_COLORMAP_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_COLORMAP_LAYOUT_FITS_HPP

#include <climits>
#include <cstdint>

namespace opencv_imgproc_detail {

// ABI safety: legacy LUT casts iterator size to int and evaluates len*3.
// This also bounds packed byte steps, color scheduling, and newer packet sums.
constexpr bool colormap_layout_fits(uint64_t rows, uint64_t cols)
{
    return rows > 0 && cols > 0 && cols <= uint64_t{INT_MAX} / 3 &&
           rows <= uint64_t{INT_MAX} / (cols * 3);
}

// ABI safety: manual snapshot addressing must not wrap or exceed ptrdiff_t;
// limit is min(SIZE_MAX, PTRDIFF_MAX). No narrowing of the parent step.
constexpr bool colormap_span_fits(uint64_t rows, uint64_t row_bytes,
                                  uint64_t step, uint64_t limit)
{
    return rows > 0 && row_bytes > 0 && step >= row_bytes &&
           row_bytes <= limit &&
           (rows == 1 || step <= (limit - row_bytes) / (rows - 1));
}

} // namespace opencv_imgproc_detail
#endif