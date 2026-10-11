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

struct Layout {
    int angle_bins;
    int scale_bins;
};

// Native range is cvCeil(span * (1 / step)), not cvCeil(span / step).
inline bool histogram_bins(double minimum, double maximum, double step,
                           int &bins) noexcept
{
    constexpr auto limit = std::numeric_limits<int>::max();
    if (!std::isfinite(minimum) || !std::isfinite(maximum) ||
        !finite_positive(step) || !(minimum < maximum))
        return false;
    const double span = maximum - minimum;
    const double reciprocal = 1.0 / step;
    if (!std::isfinite(span) || !std::isfinite(reciprocal)) return false;
    const double scaled = span * reciprocal;
    if (!std::isfinite(scaled)) return false;
    const double count = std::ceil(scaled);
    const double index = std::round(scaled);
    if (!std::isfinite(count) || !std::isfinite(index) ||
        count < 1.0 || count > double(limit - 1) || index > count)
        return false;
    bins = static_cast<int>(count);
    return true;
}

inline bool plan(int template_rows, int template_columns,
                 int scene_rows, int scene_columns,
                 const Parameters &parameters, Layout &layout) noexcept
{
    using W = std::int64_t;
    constexpr W limit = std::numeric_limits<int>::max();
    constexpr W pointer = std::numeric_limits<std::ptrdiff_t>::max();
    layout = {};
    if (!image_fits(template_rows, template_columns) ||
        !image_fits(scene_rows, scene_columns) ||
        parameters.angle_threshold <= 0 || parameters.scale_threshold <= 0 ||
        parameters.position_threshold <= 0 ||
        !(parameters.minimum_angle >= 0.0 &&
          parameters.maximum_angle <= 360.0 &&
          parameters.angle_step < 360.0))
        return false;
    int angle_bins = 0, scale_bins = 0;
    if (!histogram_bins(parameters.minimum_angle, parameters.maximum_angle,
                        parameters.angle_step, angle_bins) ||
        !histogram_bins(parameters.minimum_scale, parameters.maximum_scale,
                        parameters.scale_step, scale_bins))
        return false;
    // Divide before multiplying so the candidate product is exact in int64.
    constexpr W bins = 361;
    constexpr W cap = 1000;
    const W rows = scene_rows, columns = scene_columns;
    const W peaks = rows * columns;
    const W angle_limit = limit / 16;
    if (W(angle_bins) > angle_limit || W(scale_bins) > limit ||
        peaks > angle_limit ||
        W(scale_bins) > angle_limit / W(angle_bins) ||
        peaks > angle_limit / (W(angle_bins) * W(scale_bins)))
        return false;
    const W outputs = W(angle_bins) * W(scale_bins) * peaks;
    const W votes = (bins * cap) * cap;
    if (votes > limit || rows > limit - 1 || columns > limit - 1 ||
        (rows + 2) > pointer / 4 / (columns + 2) ||
        outputs > pointer / 16 || outputs > pointer / 12)
        return false;
    layout.angle_bins = angle_bins;
    layout.scale_bins = scale_bins;
    return true;
}

inline bool parameters_fit(const Parameters &p) noexcept
{
    Layout layout;
    return plan(1, 1, 1, 1, p, layout);
}

inline bool fits(int template_rows, int template_columns,
                 int scene_rows, int scene_columns,
                 const Parameters &parameters) noexcept
{
    Layout layout;
    return plan(template_rows, template_columns, scene_rows, scene_columns,
                parameters, layout);
}
} // namespace opencv_imgproc_guil
#endif
