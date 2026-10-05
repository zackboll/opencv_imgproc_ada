#ifndef OPENCV_IMGPROC_FLOOD_FILL_INT32_FITS_HPP
#define OPENCV_IMGPROC_FLOOD_FILL_INT32_FITS_HPP

#include <climits>
#include <cstdint>
#include <cmath>

namespace opencv_imgproc_detail {

static_assert(INT_MAX == INT32_MAX && INT_MIN == INT32_MIN,
              "native flood fill requires 32-bit int");

// ABI safety: Diff32sC1 and Diff32sC3 subtract samples in signed int.
constexpr bool flood_fill_int32_span_fits(int32_t minimum, int32_t maximum)
{
    return int64_t{maximum} - int64_t{minimum} <= INT_MAX;
}

// ABI safety: scalarToRawData/cvFloor have undefined out-of-domain conversions.
inline bool flood_fill_int32_component_fits(double value) noexcept
{
    return std::isfinite(value) && value >= INT_MIN && value <= INT_MAX;
}

} // namespace opencv_imgproc_detail
#endif