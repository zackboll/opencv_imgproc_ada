#ifndef OPENCV_IMGPROC_SQUARED_BOX_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_SQUARED_BOX_LAYOUT_FITS_HPP

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>

// Allocation-free plan for the established shifted top-left-anchor adapter.
// ABI safety: every rejection bounds adapter pointers, native signed arithmetic,
// or the reviewed UInt8 signed accumulator; this is not friendly API policy.
namespace opencv_imgproc_squared_box {
struct Layout {
    int kernel_width = 0;
    int kernel_height = 0;
    int native_width = 0;
    int native_height = 0;
    int parent_width = 0;
    int parent_height = 0;
};

inline bool plan(int rows, int columns, int depth, int channels,
                 int width, int height, int normalize, int border,
                 Layout& output) noexcept
{
    output = {};
    if (rows <= 0 || columns <= 0 || width <= 0 || height <= 0 ||
        (depth != 0 && depth != 5) || (channels != 1 && channels != 3) ||
        (normalize != 0 && normalize != 1) ||
        (border != 0 && border != 1 && border != 2 && border != 4))
        return false;

    using Wide = std::int64_t;
    constexpr Wide limit = std::numeric_limits<int>::max();
    // Native normalization-specific reduction uses ORIGINAL logical geometry.
    const Wide kw = normalize && border != 0 && columns == 1 ? 1 : width;
    const Wide kh = normalize && border != 0 && rows == 1 ? 1 : height;
    if (kw * kh > (depth == 0 ? 33025 : limit))
        return false;

    // Avoid any further native singleton reduction under BORDER_REPLICATE.
    const Wide nw = normalize && kw > 1 ? std::max(columns, 2) : columns;
    const Wide nh = normalize && kh > 1 ? std::max(rows, 2) : rows;
    const Wide pw = nw + kw - 1;
    // One extra bottom row contains the final unconditional source increment.
    const Wide ph = nh + kh;
    const Wide esz = channels * (depth == 0 ? 1 : 4);
    const Wide besz = channels * (depth == 0 ? 4 : 8);
    // All pinned builds use a 64-byte CV_MALLOC_ALIGN.
    constexpr Wide alignment = 64;
    const Wide aligned = ((nw + alignment - 1) / alignment) * alignment;
    const Wide buffer_step = aligned * besz;
    const Wide buffer_rows = std::max(kh + 3, 2 * (kh - 1) + 1);
    if (pw > limit || ph > limit || kh + 3 > limit ||
        buffer_rows > limit || pw * esz > limit ||
        std::max(kw - 1, Wide{1}) * channels > limit ||
        kw * channels > limit || pw * channels > limit ||
        aligned > limit || buffer_step > limit ||
        buffer_step * (buffer_rows - 1) > limit ||
        nw * channels * 8 > limit ||
        nw * channels * 8 * std::min(nh, buffer_rows) > limit ||
        nh + kh > limit)
        return false;

    const auto pointer_limit = std::numeric_limits<std::ptrdiff_t>::max();
    if (pw * esz * ph > pointer_limit ||
        nw * channels * 8 * nh > pointer_limit ||
        buffer_step * buffer_rows + alignment > pointer_limit)
        return false;

    output = {static_cast<int>(kw), static_cast<int>(kh),
              static_cast<int>(nw), static_cast<int>(nh),
              static_cast<int>(pw), static_cast<int>(ph)};
    return true;
}

// Map an arbitrary widened logical coordinate without iteration or negation
// of INT_MIN. Input coordinates arise from signed-int physical dimensions.
inline int border_index(std::int64_t coordinate, int length, int border) noexcept
{
    if (coordinate >= 0 && coordinate < length)
        return static_cast<int>(coordinate);
    if (border == 0)
        return -1;
    if (border == 1 || length == 1)
        return coordinate < 0 ? 0 : length - 1;
    const std::int64_t period = border == 2 ? 2LL * length : 2LL * (length - 1);
    std::int64_t value = coordinate % period;
    if (value < 0)
        value += period;
    if (value >= length)
        value = border == 2 ? period - 1 - value : period - value;
    return static_cast<int>(value);
}
} // namespace opencv_imgproc_squared_box
#endif