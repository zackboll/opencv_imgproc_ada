#ifndef OPENCV_IMGPROC_CANNY_BOX_LAYOUT_HPP
#define OPENCV_IMGPROC_CANNY_BOX_LAYOUT_HPP

#include <algorithm>
#include <climits>
#include <cstddef>
#include <cstdint>

namespace opencv_imgproc_detail {
// ABI safety: pinned Canny implementations form signed padded widths, three
// channel-expanded magnitude rows, and signed row*mapstep offsets. The 64-byte
// bound covers all fixed-width CPU dispatch variants in the qualified builds.
inline bool canny_layout(int rows, int cols, int channels) noexcept
{
    using W = int64_t;
    if (rows <= 0 || cols <= 0 || (channels != 1 && channels != 3)) return false;
    const W step = ((W(cols) + 65 + 63) / 64) * 64;
    return W(rows) + 2 <= INT_MAX && step <= INT_MAX &&
        3 * (step * channels + 64) <= INT_MAX &&
        (W(rows) + 2) * step <= std::min<int64_t>(INT_MAX, PTRDIFF_MAX) &&
        3 * (step * channels + 64) <= PTRDIFF_MAX / 4;
}

struct Box_Layout {
    int kw = 0, kh = 0, nw = 0, nh = 0, pw = 0, ph = 0;
};

// ABI safety: same shifted FilterEngine geometry as squared_box_layout_fits,
// with eight-byte source/output/buffer bounds covering every exposed depth.
// Bound each factor before its next multiplication, including on 32-bit hosts.
inline bool box_layout(int rows, int cols, int channels, int width, int height,
                       bool normalize, int border, Box_Layout &out) noexcept
{
    out = {};
    using W = int64_t;
    if (rows <= 0 || cols <= 0 || channels <= 0 || channels > 512 ||
        width <= 0 || height <= 0) return false;
    const W kw = normalize && border != 0 && cols == 1 ? 1 : width;
    const W kh = normalize && border != 0 && rows == 1 ? 1 : height;
    if (kw * kh > INT_MAX) return false;
    const W nw = normalize && kw > 1 ? std::max(cols, 2) : cols;
    const W nh = normalize && kh > 1 ? std::max(rows, 2) : rows;
    const W pw = nw + kw - 1, ph = nh + kh;
    const W aligned = ((nw + 63) / 64) * 64;
    const W step = aligned * channels * 8;
    const W ring = std::max(kh + 3, 2 * (kh - 1) + 1);
    if (pw > INT_MAX || ph > INT_MAX || ring > INT_MAX ||
        pw * channels * 8 > INT_MAX || kw * channels > INT_MAX ||
        step > INT_MAX || step * ring > INT_MAX ||
        nw * channels * 8 * std::min(nh, ring) > INT_MAX ||
        pw * channels * 8 * ph > PTRDIFF_MAX ||
        nw * channels * 8 * nh > PTRDIFF_MAX) return false;
    // OpenCV 5's small same-depth floating BlockSum allocates a signed
    // (width+kw-1+VEC_ALIGN)*(kh+1)*element-size block. This also bounds it.
    if ((pw + 64) * channels * 8 > INT_MAX ||
        (pw + 64) * channels * 8 * (kh + 1) > INT_MAX) return false;
    out = {int(kw), int(kh), int(nw), int(nh), int(pw), int(ph)};
    return true;
}
} // namespace opencv_imgproc_detail
#endif