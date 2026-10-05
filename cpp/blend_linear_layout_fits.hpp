#ifndef OPENCV_IMGPROC_BLEND_LINEAR_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_BLEND_LINEAR_LAYOUT_FITS_HPP

#include <climits>
#include <cstdint>

namespace opencv_imgproc_detail {

// Zero columns is arithmetic-safe; empty-image policy belongs to Ada.
// ABI safety: BlendLinearInvoker multiplies cols*channels in signed int.
constexpr bool blend_linear_layout_fits(int64_t columns, int64_t channels)
{
    return columns >= 0 && columns <= INT_MAX &&
           channels > 0 && channels <= INT_MAX &&
           static_cast<uint64_t>(columns) * static_cast<uint64_t>(channels)
               <= static_cast<uint64_t>(INT_MAX);
}

} // namespace opencv_imgproc_detail

#endif