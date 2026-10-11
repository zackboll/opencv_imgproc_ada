#ifndef OPENCV_IMGPROC_GUIL_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_GUIL_LAYOUT_FITS_HPP
#include <cstdint>
#include <cmath>
#include <limits>

namespace opencv_imgproc_guil {
// ABI safety: bound Canny/Sobel preprocessing, signed contour area, feature
// indices, histogram allocation and indices, position rounding, vote narrowing
// and vector-to-Mat byte widths. No allocation occurs here.
struct Parameters {
    double minimum_angle;
    double maximum_angle;
    double angle_step;
    double minimum_scale;
    double maximum_scale;
    double scale_step;
    int angle_threshold;
    int scale_threshold;
    int position_threshold;
};

inline bool finite_positive(double value) noexcept
{
    return std::isfinite(value) && value > 0.0;
}

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
    // Size::area multiplies signed ints before contour reservation.
    return h + 2 <= limit && w + 256 <= limit &&
        3 * (map_width + 128) <= limit && filter_step * 6 <= limit &&
        (h + 2) * map_width <= std::numeric_limits<unsigned>::max() &&
        (h + 2) * map_width <= pointer && h * w * 4 <= pointer &&
        h * w <= limit &&
        ((w + 127) / 64) * ((h + 127) / 64) <= limit;
}

inline bool parameters_fit(const Parameters &p) noexcept
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    if (!std::isfinite(p.minimum_angle) || !std::isfinite(p.maximum_angle) ||
        !finite_positive(p.angle_step) || !finite_positive(p.minimum_scale) ||
        !std::isfinite(p.maximum_scale) || !finite_positive(p.scale_step) ||
        p.angle_threshold <= 0 || p.scale_threshold <= 0 ||
        p.position_threshold <= 0)
        return false;
    if (!(p.minimum_angle >= 0.0 && p.minimum_angle < p.maximum_angle &&
          p.maximum_angle <= 360.0 && p.angle_step < 360.0 &&
          p.minimum_scale < p.maximum_scale))
        return false;
    const double angle_span = p.maximum_angle - p.minimum_angle;
    const double scale_span = p.maximum_scale - p.minimum_scale;
    const double angle_reciprocal = 1.0 / p.angle_step;
    const double scale_reciprocal = 1.0 / p.scale_step;
    if (!std::isfinite(angle_reciprocal) || !std::isfinite(scale_reciprocal) ||
        !std::isfinite(angle_span * angle_reciprocal) ||
        !std::isfinite(scale_span * scale_reciprocal))
        return false;
    // cvCeil result and the extra histogram bin must fit signed int.
    const double angle_bins = std::ceil(angle_span * angle_reciprocal);
    const double scale_bins = std::ceil(scale_span * scale_reciprocal);
    if (angle_bins < 1.0 || scale_bins < 1.0 ||
        angle_bins > double(limit - 1) || scale_bins > double(limit - 1))
        return false;
    // A value equal to the maximum rounds into the extra bin. The next
    // representable step past that maximum would index one further.
    const double angle_index =
        std::round(angle_span * angle_reciprocal);
    const double scale_index =
        std::round(scale_span * scale_reciprocal);
    return std::isfinite(angle_index) && std::isfinite(scale_index) &&
        angle_index <= angle_bins && scale_index <= scale_bins;
}

inline bool fits(int template_rows, int template_columns,
                 int scene_rows, int scene_columns,
                 const Parameters &parameters) noexcept
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    constexpr W pointer = std::numeric_limits<std::ptrdiff_t>::max();
    if (!image_fits(template_rows, template_columns) ||
        !image_fits(scene_rows, scene_columns) ||
        !parameters_fit(parameters))
        return false;
    const double angle_bins = std::ceil(
        (parameters.maximum_angle - parameters.minimum_angle) /
        parameters.angle_step);
    const double scale_bins = std::ceil(
        (parameters.maximum_scale - parameters.minimum_scale) /
        parameters.scale_step);
    // One local-maximum peak per spatial cell, per accepted hypothesis.
    // 361 orientation bins and the 1000-entry cap bound votes per cell.
    constexpr W bins = 361;
    constexpr W cap = 1000;
    const W peaks = W(scene_rows) * scene_columns;
    if (angle_bins > double(limit / 16) || scale_bins > double(limit) ||
        peaks > limit / 16 ||
        angle_bins * scale_bins > double(limit) / double(peaks))
        return false;
    const W outputs = W(angle_bins) * W(scale_bins) * peaks;
    const W votes = bins * cap * cap;
    // Position centers are cvRound of a value strictly below the dimension.
    return outputs <= limit / 16 && votes <= limit &&
        W(scene_rows) <= limit - 1 && W(scene_columns) <= limit - 1 &&
        (W(scene_rows) + 2) * (W(scene_columns) + 2) <= pointer / 4 &&
        outputs * 16 <= pointer && outputs * 12 <= pointer;
}
} // namespace opencv_imgproc_guil
#endif
