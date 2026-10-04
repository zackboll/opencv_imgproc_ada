#ifndef OPENCV_IMGPROC_MORPHOLOGY_EXPANSION_FITS_HPP
#define OPENCV_IMGPROC_MORPHOLOGY_EXPANSION_FITS_HPP

#include <cstdint>
#include <limits>

namespace opencv_imgproc_detail {

// Inputs have already passed positive signed-int geometry/anchor preflight.
// Sparse masks never enter morphOp's rectangular iteration collapse.
inline bool morphology_expansion_fits(
    std::int64_t width, std::int64_t height, std::int64_t channels,
    std::int64_t anchor_x, std::int64_t anchor_y,
    std::int32_t iterations, bool full_mask) noexcept
{
    if (!full_mask || iterations <= 1 || width * height <= 1)
        return true;
    const std::int64_t limit = std::numeric_limits<int>::max();
    const std::int64_t n = iterations;
    const std::int64_t expanded_width = width + (n - 1) * (width - 1);
    const std::int64_t expanded_height = height + (n - 1) * (height - 1);
    return expanded_width <= limit && expanded_height <= limit &&
        expanded_width <= limit / channels &&
        anchor_x * n <= limit && anchor_y * n <= limit;
}

} // namespace opencv_imgproc_detail

#endif