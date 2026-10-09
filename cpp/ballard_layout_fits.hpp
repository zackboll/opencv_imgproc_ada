#ifndef OPENCV_IMGPROC_BALLARD_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_BALLARD_LAYOUT_FITS_HPP
#include <algorithm>
#include <cstdint>
#include <cstddef>
#include <limits>

namespace opencv_imgproc_ballard {
// ABI safety: bound Canny padding/buffers, Sobel signed strides/batches,
// histogram allocation, Point subtraction, votes and vector-to-Mat byte widths.
// No allocation occurs here, so extreme geometries can be tested directly.
inline bool image_fits(int rows, int cols) noexcept
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    constexpr W pointer = std::numeric_limits<std::ptrdiff_t>::max();
    if (rows <= 0 || cols <= 0) return false;
    const W h = rows, w = cols;
    // Maximum pinned SIMD padding is 128 bytes, including scalable builds.
    const W map_width = ((w + 129 + 127) / 128) * 128;
    const W filter_step = ((w + 63) / 64) * 64 * 4;
    return h + 2 <= limit && w + 256 <= limit &&
        3 * (map_width + 128) <= limit && filter_step * 6 <= limit &&
        (h + 2) * map_width <= std::numeric_limits<unsigned>::max() &&
        (h + 2) * map_width <= pointer && h * w * 4 <= pointer &&
        ((w + 127) / 64) * ((h + 127) / 64) <= limit;
}

inline bool fits(int tr, int tc, int sr, int sc) noexcept
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    if (!image_fits(tr, tc) || !image_fits(sr, sc)) return false;
    const W ta = W(tr) * tc, sa = W(sr) * sc;
    const W peaks = (sa + 1) / 2;
    return W(sr) - 1 + tr / 2 <= limit &&
        W(sc) - 1 + tc / 2 <= limit && std::min(ta, sa) <= limit &&
        ta <= std::numeric_limits<std::ptrdiff_t>::max() / 8 &&
        peaks <= limit / 16 &&
        (W(sr) + 2) * (W(sc) + 2) <=
            std::numeric_limits<std::ptrdiff_t>::max() / 4;
}
} // namespace opencv_imgproc_ballard
#endif