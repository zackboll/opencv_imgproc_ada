#ifndef OPENCV_IMGPROC_MASKED_TEMPLATE_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_MASKED_TEMPLATE_LAYOUT_FITS_HPP

#include <opencv2/core.hpp>
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace opencv_imgproc_masked_template {
// ABI safety: ipp_matchTemplate evaluates template.area()*4 in signed int.
// Snapshot/output row steps fit int because their widths do not exceed Source.
inline bool unmasked_fits(int rows, int cols) noexcept
{
    return rows > 0 && cols > 0 && std::int64_t(rows) * cols <=
        std::numeric_limits<int>::max() / 4;
}
// Allocation-free preflight for the C1 Float32 crossCorr path in all three
// qualified tags. OpenCV remains trusted for its DFT implementation.
inline bool fits(int rows, int cols, int tr, int tc)
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    const W pointer = std::numeric_limits<std::ptrdiff_t>::max();
    if (rows <= 0 || cols <= 0 || tr <= 0 || tc <= 0 ||
        tr > rows || tc > cols)
        return false;
    const W rr = W(rows) - tr + 1, rc = W(cols) - tc + 1;
    // Native Mat arithmetic/reductions and signed widths; Float32 snapshots.
    if (W(rows) * cols > limit || W(tr) * tc > limit || rr * rc > limit ||
        W(cols) * 4 > limit || W(rows) * cols > pointer / 4 ||
        W(tr) * tc > pointer / 4 || rr * rc > pointer / 4 ||
        W(rows) + tr - 1 > limit || W(cols) + tc - 1 > limit ||
        W(tr) * 9 > 2 * limit || W(tc) * 9 > 2 * limit)
        return false;
    // cvRound(4.5 * template), then clamp to correlation size.
    const W bw = std::min<W>(std::max<W>(cvRound(tc * 4.5), 257 - W(tc)), rc);
    const W bh = std::min<W>(std::max<W>(cvRound(tr * 4.5), 257 - W(tr)), rr);
    if (bw + tc - 1 > limit || bh + tr - 1 > limit)
        return false;
    const W dw = std::max(cv::getOptimalDFTSize(int(bw + tc - 1)), 2);
    const W dh = cv::getOptimalDFTSize(int(bh + tr - 1));
    // crossCorr casts the Float64 DFT row step to int for HAL::apply.
    // DFT backend probes/parallel partitioning also form width*height in int.
    if (dh <= 0 || dw * 8 > limit || dw * dh > limit ||
        dw * dh > pointer / 8)
        return false;
    const W xb = std::min<W>(dw - tc + 1, rc);
    const W yb = std::min<W>(dh - tr + 1, rr);
    if (xb <= 0 || yb <= 0 || rc + xb - 1 > limit || rr + yb - 1 > limit)
        return false;
    return ((rc + xb - 1) / xb) * ((rr + yb - 1) / yb) <= limit;
}

inline bool span_fits(int rows, int cols, std::size_t step) noexcept
{
    const auto limit = static_cast<std::uint64_t>(
        std::numeric_limits<std::ptrdiff_t>::max());
    return rows > 0 && cols > 0 && step >= static_cast<std::size_t>(cols) &&
        step <= limit && static_cast<std::uint64_t>(rows - 1) <=
        (limit - static_cast<std::uint64_t>(cols)) / step;
}
}
#endif