#ifndef OPENCV_IMGPROC_SUBPIXEL_PATCH_GUARD_HPP
#define OPENCV_IMGPROC_SUBPIXEL_PATCH_GUARD_HPP

#include <opencv2/core.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <climits>

namespace opencv_imgproc_subpixel {
struct Guard {
    int x = 0, y = 0;
    int left = 0, right = 0, top = 0, bottom = 0;
    int columns = 0, rows = 0;
    bool direct = false;
};

// Allocation-free preflight of the exact native binary32 coordinate model.
inline bool plan(int columns, int rows, int width, int height,
                 float cx, float cy, int channels, int input_bytes,
                 int output_bytes, bool promote_u8, Guard &g) {
    if (columns <= 0 || rows <= 0 || width <= 0 || height <= 0 ||
        (channels != 1 && channels != 3) ||
        (input_bytes != 1 && input_bytes != 4) ||
        (output_bytes != 1 && output_bytes != 4) ||
        !std::isfinite(cx) || !std::isfinite(cy) ||
        cx < 0 || cy < 0 || double(cx) >= columns || double(cy) >= rows)
        return false;
    const float ax = cx - (width - 1) * 0.5f;
    const float ay = cy - (height - 1) * 0.5f;
    // ABI safety: float-to-int conversion in cvFloor must be representable.
    if (double(ax) < INT_MIN || double(ax) > INT_MAX ||
        double(ay) < INT_MIN || double(ay) > INT_MAX)
        return false;
    g.x = cvFloor(ax);
    g.y = cvFloor(ay);
    const int64_t end_x = int64_t(g.x) + width;
    const int64_t end_y = int64_t(g.y) + height;
    // ABI safety: signed channel indexing includes the floor+1 neighbour.
    if (int64_t(width) * channels + channels - 1 > INT_MAX ||
        int64_t(std::max(0, g.x)) * channels > INT_MAX)
        return false;
    // ABI safety: the 8u32f specialization adds signed origins and sizes.
    if (promote_u8 && (end_x > INT_MAX || end_y > INT_MAX))
        return false;
    // ABI safety: IPP destination byte steps are narrowed to signed int.
    if (channels == 1 && int64_t(width) * output_bytes > INT_MAX)
        return false;
    g.direct = g.x >= 0 && g.y >= 0 && end_x < columns && end_y < rows;
    const int64_t left = std::max<int64_t>(0, -int64_t(g.x));
    const int64_t top = std::max<int64_t>(0, -int64_t(g.y));
    const int64_t right = std::max<int64_t>(0, end_x - (columns - 1));
    const int64_t bottom = std::max<int64_t>(0, end_y - (rows - 1));
    const int64_t padded_columns = columns + left + right;
    const int64_t padded_rows = rows + top + bottom;
    // ABI safety: destination dimensions and adjustRect pixel-byte products
    // must fit signed int. Preserve the reviewed extra physical bottom row
    // and byte-width boundary even with bytewise private guard construction.
    if (padded_columns > INT_MAX || padded_rows > INT_MAX ||
        (!g.direct && padded_rows == INT_MAX) ||
        (!g.direct && padded_columns * channels * input_bytes > INT_MAX))
        return false;
    g.left = int(left); g.right = int(right);
    g.top = int(top); g.bottom = int(bottom);
    g.columns = int(padded_columns); g.rows = int(padded_rows);
    return true;
}

inline bool input_step_safe(int channels, size_t step) {
    return channels != 1 || step <= size_t(INT_MAX);
}
} // namespace opencv_imgproc_subpixel
#endif