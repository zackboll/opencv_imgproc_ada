#include "opencv_imgproc_shim.h"
#include "opencv_core_module_bridge.hpp"

#include <opencv2/imgproc.hpp>

#include <array>
#include <cfloat>
#include <cstdio>
#include <cmath>
#include <algorithm>
#include <cstdint>
#include <exception>
#include <limits>
#include <utility>
#include <vector>

struct opencv_imgproc_contours_handle {
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
};

struct opencv_imgproc_hough_lines_handle {
    std::vector<cv::Vec2f> lines;
};

struct opencv_imgproc_hough_segments_handle {
    std::vector<cv::Vec4i> segments;
};

struct opencv_imgproc_hough_circles_handle {
    std::vector<cv::Vec3f> circles;
};

// Normalized (rho, theta, votes) lines shared by raster Hough lines with
// votes (native Vec3f) and HoughLinesPointSet (native Vec3d
// (votes, rho, theta)).
struct opencv_imgproc_hough_line_evidence_handle {
    std::vector<opencv_imgproc_hough_line_evidence> lines;
};

// Radius-finding HOUGH_GRADIENT output (x, y, radius, votes). Never filled
// in centers-only mode, whose fourth native component is an index.
struct opencv_imgproc_hough_circle_evidence_handle {
    std::vector<cv::Vec4f> circles;
};

// Owned buildPyramid result. levels[0] may be a shallow header over the
// shim-local logical source; copy_level always publishes deep clones.
struct opencv_imgproc_pyramid_handle {
    std::vector<cv::Mat> levels;
};

namespace {

void clear_error() noexcept;
opencv_imgproc_status invalid_argument(const char *message) noexcept;
opencv_imgproc_status translate_current_exception() noexcept;

// OpenCV 4.1/4.10/5.0 ipp_integral declines C2+ and tilted before casting
// strides. These are precisely the documented public combinations reaching
// its IPP calls; other supported combinations use HAL/SIMD/scalar fallback.
bool integral_may_use_ipp(int source_depth, int channels, bool squares,
                          bool tilted, int sum_depth, int square_depth) noexcept
{
    if (channels != 1 || tilted)
        return false;
    if (squares)
        return source_depth == CV_8U && square_depth == CV_64F &&
               (sum_depth == CV_32S || sum_depth == CV_32F);
    return (source_depth == CV_8U &&
            (sum_depth == CV_32S || sum_depth == CV_32F)) ||
           (source_depth == CV_32F && sum_depth == CV_32F);
}

// These checks precede cv::integral's signed Size construction and scalar
// width/step/index arithmetic (4.1, 4.10 and 5.0 sumpixels implementations).
opencv_imgproc_status integral_preflight(const cv::Mat &src, int sum_selector,
                                          int square_selector, bool squares,
                                          bool tilted, int &sum_depth,
                                          int &square_depth)
{
    // ABI safety: integral assumes a nonempty 2-D image and accesses its rows.
    if (src.empty() || src.dims != 2 || src.channels() < 1 ||
        (src.depth() != CV_8U && src.depth() != CV_32F && src.depth() != CV_64F))
        return invalid_argument("Integral source must be nonempty 2-D UInt8, Float32 or Float64");
    if (sum_selector < 0 || sum_selector > 2 ||
        (squares && (square_selector < 0 || square_selector > 1)))
        return invalid_argument("Invalid integral depth selector");
    sum_depth = sum_selector == 0 ? CV_32S : sum_selector == 1 ? CV_32F : CV_64F;
    square_depth = square_selector == 0 ? CV_32F : CV_64F;
    // ABI safety: rejecting unsupported dispatch before native allocation
    // prevents partially initialized multi-output results on failure.
    if ((src.depth() == CV_32F && sum_selector == 0) ||
        (src.depth() == CV_64F && sum_selector != 2) ||
        (squares && square_selector == 0 && sum_selector == 2) ||
        (squares && src.depth() == CV_64F && square_selector != 1))
        return invalid_argument("Unsupported integral source/output depth pairing");

    const uint64_t limit = static_cast<uint64_t>(std::numeric_limits<int>::max());
    const uint64_t cols = static_cast<uint64_t>(src.cols);
    const uint64_t cn = static_cast<uint64_t>(src.channels());
    // ABI safety: cv::integral builds Size(cols+1, rows+1) using signed int.
    if (src.rows >= std::numeric_limits<int>::max() || cols >= limit)
        return invalid_argument("Integral output dimension overflows int");
    // ABI safety: integral_ uses int width *= cn, width+cn scratch,
    // and x +/- cn; output element stride is (cols+1)*cn.
    const uint64_t scalar_width = (cols + 1) * cn;
    // ABI safety: tilted[x - tiltedstep - cn] may negate step+cn
    // in a signed int intermediate even when each operand fits separately.
    if (scalar_width > limit || (tilted && scalar_width > limit - cn))
        return invalid_argument("Integral channel-expanded width overflows int");
    // ABI safety: integral_ narrows source.step / sizeof(T) to signed int.
    if (src.step[0] / src.elemSize1() > limit)
        return invalid_argument("Integral source stride overflows int");
    // ABI safety: continuous output row strides are scalar_width elements;
    // tilted accesses previous row with x +/- cn. All fit int above.
    if (integral_may_use_ipp(src.depth(), src.channels(), squares, tilted,
                             sum_depth, square_depth)) {
        // ABI safety: ipp_integral narrows the original source byte stride
        // directly with (int)srcstep before calling IPP (including Regions).
        if (src.step[0] > limit)
            return invalid_argument("Integral IPP source byte stride overflows int");
        const uint64_t sum_element_size = sum_depth == CV_64F
            ? sizeof(double) : sum_depth == CV_32F ? sizeof(float) : sizeof(int32_t);
        // ABI safety: ipp_integral casts sumstep, expressed in bytes,
        // directly to int. Check before native output allocation.
        if (scalar_width > limit / sum_element_size)
            return invalid_argument("Integral IPP sum byte stride overflows int");
        if (squares) {
            const uint64_t square_element_size = square_depth == CV_32F
                ? sizeof(float) : sizeof(double);
            // ABI safety: ipp_integral casts sqsumstep, expressed in bytes,
            // directly to int. Check before native output allocation.
            if (scalar_width > limit / square_element_size)
                return invalid_argument("Integral IPP squared byte stride overflows int");
        }
    }
    if (sum_selector == 0 && src.depth() == CV_8U) {
        // ABI safety: signed Int32 scalar accumulation otherwise overflows.
        // Saturate at INT_MAX+1 without overflowing the widened counters.
        std::vector<uint64_t> totals(static_cast<size_t>(cn), 0);
        for (int y = 0; y < src.rows; ++y) {
            const uint8_t *row = src.ptr<uint8_t>(y);
            for (uint64_t x = 0; x < cols; ++x)
                for (uint64_t c = 0; c < cn; ++c) {
                    uint64_t &total = totals[static_cast<size_t>(c)];
                    total += row[x * cn + c];
                    if (total > limit)
                        return invalid_argument("Integral Int32 channel total exceeds INT_MAX");
                }
        }
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status integral_execute(const opencv_core_mat_handle *source,
    int32_t sum_selector, int32_t square_selector, opencv_core_mat_handle *sum,
    opencv_core_mat_handle *squared, opencv_core_mat_handle *tilted)
{
    clear_error();
    if (!source || !sum || (squared && squared == sum) ||
        (tilted && (tilted == sum || tilted == squared)))
        return invalid_argument("Invalid or duplicate integral handle");
    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst_sum = nullptr, *dst_sq = nullptr, *dst_tilt = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK ||
            opencv_core_module_output_mat(sum, &dst_sum) != OPENCV_CORE_OK ||
            (squared && opencv_core_module_output_mat(squared, &dst_sq) != OPENCV_CORE_OK) ||
            (tilted && opencv_core_module_output_mat(tilted, &dst_tilt) != OPENCV_CORE_OK))
            return invalid_argument("Invalid integral Mat handle");
        int sd = 0, qd = 0;
        opencv_imgproc_status status = integral_preflight(*src, sum_selector,
            square_selector, squared != nullptr, tilted != nullptr, sd, qd);
        if (status != OPENCV_IMGPROC_OK) return status;
        cv::Mat local_sum, local_sq, local_tilt;
        if (tilted)
            cv::integral(*src, local_sum, local_sq, local_tilt, sd, qd);
        else if (squared)
            cv::integral(*src, local_sum, local_sq, sd, qd);
        else
            cv::integral(*src, local_sum, sd);
        *dst_sum = std::move(local_sum);
        if (squared) *dst_sq = std::move(local_sq);
        if (tilted) *dst_tilt = std::move(local_tilt);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

constexpr std::size_t error_message_capacity = 1024;
thread_local char last_error_message[error_message_capacity] = "";

void clear_error() noexcept
{
    last_error_message[0] = '\0';
}

void set_error(const char *message) noexcept
{
    const char *safe_message =
        message == nullptr
            ? "No diagnostic message is available"
            : message;

    std::snprintf(
        last_error_message,
        error_message_capacity,
        "%s",
        safe_message);
}

opencv_imgproc_status invalid_argument(const char *message) noexcept
{
    set_error(message);
    return OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT;
}

opencv_imgproc_status translate_current_exception() noexcept
{
    try {
        throw;
    } catch (const cv::Exception &error) {
        set_error(error.what());
        return OPENCV_IMGPROC_ERROR_OPENCV;
    } catch (const std::exception &error) {
        set_error(error.what());
        return OPENCV_IMGPROC_ERROR_STD;
    } catch (...) {
        set_error("Unknown C++ exception");
        return OPENCV_IMGPROC_ERROR_UNKNOWN;
    }
}

struct color_conversion_spec {
    int code;
    int source_channels;
    int destination_channels;
    bool nonlinear;
};

// Only these selected conversions can enter CvtColorIPPLoop_Invoker on
// OpenCV 4.1/4.10/5.0. Standard-range HSV/HLS and sRGB Lab/Luv bypass it.
bool color_may_use_ipp(int32_t selector, int depth) noexcept
{
    if (selector <= OPENCV_IMGPROC_COLOR_RGBA_TO_GRAY)
        return depth == CV_32F;
    if (selector == OPENCV_IMGPROC_COLOR_GRAY_TO_BGR ||
        selector == OPENCV_IMGPROC_COLOR_GRAY_TO_RGB)
        return depth != CV_8U; // 8UC3 Gray expansion is disabled by OpenCV.
    if (selector <= OPENCV_IMGPROC_COLOR_RGBA_TO_BGRA)
        return true; // Remaining Gray-to-alpha and channel rearrangements.
    if (selector <= OPENCV_IMGPROC_COLOR_XYZ_TO_RGB)
        return depth != CV_32F;
    return selector >= OPENCV_IMGPROC_COLOR_BGR_TO_YUV &&
           selector <= OPENCV_IMGPROC_COLOR_YUV_TO_RGB && depth == CV_8U;
}

bool color_spec(int32_t conversion, color_conversion_spec &spec) noexcept
{
    // Semantic selectors are maintained by the private Ada interop layer;
    // the table intentionally does not expose OpenCV's code integers.
    static const color_conversion_spec conversions[] = {
        {cv::COLOR_BGR2GRAY, 3, 1, false},
        {cv::COLOR_RGB2GRAY, 3, 1, false},
        {cv::COLOR_BGRA2GRAY, 4, 1, false},
        {cv::COLOR_RGBA2GRAY, 4, 1, false},
        {cv::COLOR_GRAY2BGR, 1, 3, false},
        {cv::COLOR_GRAY2RGB, 1, 3, false},
        {cv::COLOR_GRAY2BGRA, 1, 4, false},
        {cv::COLOR_GRAY2RGBA, 1, 4, false},
        {cv::COLOR_BGR2RGB, 3, 3, false},
        {cv::COLOR_RGB2BGR, 3, 3, false},
        {cv::COLOR_BGR2BGRA, 3, 4, false},
        {cv::COLOR_RGB2RGBA, 3, 4, false},
        {cv::COLOR_BGR2RGBA, 3, 4, false},
        {cv::COLOR_RGB2BGRA, 3, 4, false},
        {cv::COLOR_BGRA2BGR, 4, 3, false},
        {cv::COLOR_RGBA2RGB, 4, 3, false},
        {cv::COLOR_RGBA2BGR, 4, 3, false},
        {cv::COLOR_BGRA2RGB, 4, 3, false},
        {cv::COLOR_BGRA2RGBA, 4, 4, false},
        {cv::COLOR_RGBA2BGRA, 4, 4, false},
        {cv::COLOR_BGR2XYZ, 3, 3, false},
        {cv::COLOR_RGB2XYZ, 3, 3, false},
        {cv::COLOR_XYZ2BGR, 3, 3, false},
        {cv::COLOR_XYZ2RGB, 3, 3, false},
        {cv::COLOR_BGR2YCrCb, 3, 3, false},
        {cv::COLOR_RGB2YCrCb, 3, 3, false},
        {cv::COLOR_YCrCb2BGR, 3, 3, false},
        {cv::COLOR_YCrCb2RGB, 3, 3, false},
        {cv::COLOR_BGR2YUV, 3, 3, false},
        {cv::COLOR_RGB2YUV, 3, 3, false},
        {cv::COLOR_YUV2BGR, 3, 3, false},
        {cv::COLOR_YUV2RGB, 3, 3, false},
        {cv::COLOR_BGR2HSV, 3, 3, true},
        {cv::COLOR_RGB2HSV, 3, 3, true},
        {cv::COLOR_HSV2BGR, 3, 3, true},
        {cv::COLOR_HSV2RGB, 3, 3, true},
        {cv::COLOR_BGR2HLS, 3, 3, true},
        {cv::COLOR_RGB2HLS, 3, 3, true},
        {cv::COLOR_HLS2BGR, 3, 3, true},
        {cv::COLOR_HLS2RGB, 3, 3, true},
        {cv::COLOR_BGR2Lab, 3, 3, true},
        {cv::COLOR_RGB2Lab, 3, 3, true},
        {cv::COLOR_Lab2BGR, 3, 3, true},
        {cv::COLOR_Lab2RGB, 3, 3, true},
        {cv::COLOR_BGR2Luv, 3, 3, true},
        {cv::COLOR_RGB2Luv, 3, 3, true},
        {cv::COLOR_Luv2BGR, 3, 3, true},
        {cv::COLOR_Luv2RGB, 3, 3, true}
    };
    static_assert(sizeof(conversions) / sizeof(conversions[0]) ==
                  OPENCV_IMGPROC_COLOR_LUV_TO_RGB + 1,
                  "semantic color selector table must cover the C ABI");
    if (conversion < 0 || conversion >= static_cast<int32_t>(sizeof(conversions) / sizeof(conversions[0])))
        return false;
    spec = conversions[conversion];
    return true;
}

bool to_opencv_interpolation(
    int32_t interpolation,
    int &opencv_interpolation) noexcept
{
    switch (interpolation) {
    case OPENCV_IMGPROC_INTER_NEAREST:
        opencv_interpolation = cv::INTER_NEAREST;
        return true;

    case OPENCV_IMGPROC_INTER_LINEAR:
        opencv_interpolation = cv::INTER_LINEAR;
        return true;

    case OPENCV_IMGPROC_INTER_CUBIC:
        opencv_interpolation = cv::INTER_CUBIC;
        return true;

    case OPENCV_IMGPROC_INTER_AREA:
        opencv_interpolation = cv::INTER_AREA;
        return true;

    case OPENCV_IMGPROC_INTER_LANCZOS4:
        opencv_interpolation = cv::INTER_LANCZOS4;
        return true;

    default:
        return false;
    }
}

bool to_opencv_border(int32_t border, int &opencv_border) noexcept
{
    switch (border) {
    case OPENCV_IMGPROC_BORDER_CONSTANT:
        opencv_border = cv::BORDER_CONSTANT;
        return true;

    case OPENCV_IMGPROC_BORDER_REPLICATE:
        opencv_border = cv::BORDER_REPLICATE;
        return true;

    case OPENCV_IMGPROC_BORDER_REFLECT:
        opencv_border = cv::BORDER_REFLECT;
        return true;

    case OPENCV_IMGPROC_BORDER_REFLECT_101:
        opencv_border = cv::BORDER_REFLECT_101;
        return true;

    default:
        return false;
    }
}

bool to_opencv_morphology_border(int32_t border, int &opencv_border) noexcept
{
    if (!to_opencv_border(border, opencv_border)) {
        return false;
    }

    // Region semantics: BORDER_ISOLATED prevents native morphOp from using
    // locateROI() to read pixels outside the logical Source view.
    opencv_border |= cv::BORDER_ISOLATED;
    return true;
}

bool to_opencv_pyramid_down_border(int32_t border, int &opencv_border) noexcept
{
    switch (border) {
    case OPENCV_IMGPROC_BORDER_REPLICATE:
        opencv_border = cv::BORDER_REPLICATE;
        return true;

    case OPENCV_IMGPROC_BORDER_REFLECT:
        opencv_border = cv::BORDER_REFLECT;
        return true;

    case OPENCV_IMGPROC_BORDER_REFLECT_101:
        opencv_border = cv::BORDER_REFLECT_101;
        return true;

    case OPENCV_IMGPROC_BORDER_WRAP:
        opencv_border = cv::BORDER_WRAP;
        return true;

    default:
        return false;
    }
}

bool to_opencv_derivative_depth(
    int32_t depth,
    int &opencv_depth) noexcept
{
    switch (depth) {
    case OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH:
        opencv_depth = -1;
        return true;
    case OPENCV_IMGPROC_DERIVATIVE_INT16:
        opencv_depth = CV_16S;
        return true;
    case OPENCV_IMGPROC_DERIVATIVE_FLOAT32:
        opencv_depth = CV_32F;
        return true;
    case OPENCV_IMGPROC_DERIVATIVE_FLOAT64:
        opencv_depth = CV_64F;
        return true;
    default:
        return false;
    }
}

bool to_opencv_kernel_coefficient_depth(
    int32_t depth,
    int &opencv_depth) noexcept
{
    switch (depth) {
    case OPENCV_IMGPROC_GAUSSIAN_KERNEL_FLOAT32:
        opencv_depth = CV_32F;
        return true;
    case OPENCV_IMGPROC_GAUSSIAN_KERNEL_FLOAT64:
        opencv_depth = CV_64F;
        return true;
    default:
        return false;
    }
}

bool to_opencv_gaussian_kernel_depth(
    int32_t depth,
    int &opencv_depth) noexcept
{
    return to_opencv_kernel_coefficient_depth(depth, opencv_depth);
}

bool to_opencv_sobel_kernel(int32_t kernel, int &opencv_kernel) noexcept
{
    switch (kernel) {
    case OPENCV_IMGPROC_SOBEL_KERNEL_1:
        opencv_kernel = 1;
        return true;
    case OPENCV_IMGPROC_SOBEL_KERNEL_3:
        opencv_kernel = 3;
        return true;
    case OPENCV_IMGPROC_SOBEL_KERNEL_5:
        opencv_kernel = 5;
        return true;
    case OPENCV_IMGPROC_SOBEL_KERNEL_7:
        opencv_kernel = 7;
        return true;
    default:
        return false;
    }
}

bool to_opencv_derivative_axis(
    int32_t axis,
    int &dx,
    int &dy) noexcept
{
    switch (axis) {
    case OPENCV_IMGPROC_DERIVATIVE_X:
        dx = 1;
        dy = 0;
        return true;
    case OPENCV_IMGPROC_DERIVATIVE_Y:
        dx = 0;
        dy = 1;
        return true;
    default:
        return false;
    }
}

bool valid_sobel_orders(
    int32_t x_order,
    int32_t y_order,
    int kernel_size) noexcept
{
    const int effective_kernel_size = kernel_size == 1 ? 3 : kernel_size;
    return x_order >= 0 && y_order >= 0
        && (x_order != 0 || y_order != 0)
        && x_order < effective_kernel_size
        && y_order < effective_kernel_size;
}

bool to_opencv_morphology_shape(int32_t shape, int &opencv_shape) noexcept
{
    switch (shape) {
    case OPENCV_IMGPROC_MORPH_RECTANGLE:
        opencv_shape = cv::MORPH_RECT;
        return true;

    case OPENCV_IMGPROC_MORPH_CROSS:
        opencv_shape = cv::MORPH_CROSS;
        return true;

    case OPENCV_IMGPROC_MORPH_ELLIPSE:
        opencv_shape = cv::MORPH_ELLIPSE;
        return true;

    default:
        return false;
    }
}

bool to_opencv_morphology_operation(
    int32_t operation,
    int &opencv_operation) noexcept
{
    switch (operation) {
    case OPENCV_IMGPROC_MORPH_OPEN:
        opencv_operation = cv::MORPH_OPEN;
        return true;

    case OPENCV_IMGPROC_MORPH_CLOSE:
        opencv_operation = cv::MORPH_CLOSE;
        return true;

    case OPENCV_IMGPROC_MORPH_GRADIENT:
        opencv_operation = cv::MORPH_GRADIENT;
        return true;

    case OPENCV_IMGPROC_MORPH_TOP_HAT:
        opencv_operation = cv::MORPH_TOPHAT;
        return true;

    case OPENCV_IMGPROC_MORPH_BLACK_HAT:
        opencv_operation = cv::MORPH_BLACKHAT;
        return true;

    default:
        return false;
    }
}

enum class morphology_operation {
    erosion,
    dilation
};

opencv_imgproc_status apply_morphology(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border,
    morphology_operation operation)
{
    if (kernel_width <= 0)
        return invalid_argument("morphology kernel width must be positive");
    if (kernel_height <= 0)
        return invalid_argument("morphology kernel height must be positive");
    if (iterations <= 0)
        return invalid_argument("morphology iterations must be positive");
    return opencv_imgproc_morphology_request(source, destination,
        operation == morphology_operation::erosion ? 0 : 1, 0, nullptr,
        kernel_width, kernel_height, shape, 0, 0, 0, iterations, border,
        0, nullptr);
}

bool to_opencv_canny_aperture(int32_t selector, int &aperture) noexcept
{
    switch (selector) {
    case OPENCV_IMGPROC_CANNY_APERTURE_3:
        aperture = 3;
        return true;

    case OPENCV_IMGPROC_CANNY_APERTURE_5:
        aperture = 5;
        return true;

    case OPENCV_IMGPROC_CANNY_APERTURE_7:
        aperture = 7;
        return true;

    default:
        return false;
    }
}

bool to_opencv_canny_gradient_norm(
    int32_t selector,
    bool &l2_gradient) noexcept
{
    switch (selector) {
    case OPENCV_IMGPROC_CANNY_GRADIENT_L1:
        l2_gradient = false;
        return true;

    case OPENCV_IMGPROC_CANNY_GRADIENT_L2:
        l2_gradient = true;
        return true;

    default:
        return false;
    }
}

bool to_opencv_threshold_mode(int32_t selector, int &opencv_mode) noexcept
{
    switch (selector) {
    case OPENCV_IMGPROC_THRESHOLD_BINARY:
        opencv_mode = cv::THRESH_BINARY;
        return true;
    case OPENCV_IMGPROC_THRESHOLD_BINARY_INVERSE:
        opencv_mode = cv::THRESH_BINARY_INV;
        return true;
    case OPENCV_IMGPROC_THRESHOLD_TRUNCATE:
        opencv_mode = cv::THRESH_TRUNC;
        return true;
    case OPENCV_IMGPROC_THRESHOLD_TO_ZERO:
        opencv_mode = cv::THRESH_TOZERO;
        return true;
    case OPENCV_IMGPROC_THRESHOLD_TO_ZERO_INVERSE:
        opencv_mode = cv::THRESH_TOZERO_INV;
        return true;
    default:
        return false;
    }
}

bool to_opencv_automatic_threshold_method(
    int32_t selector,
    int &opencv_flag) noexcept
{
    switch (selector) {
    case OPENCV_IMGPROC_AUTO_THRESHOLD_OTSU:
        opencv_flag = cv::THRESH_OTSU;
        return true;
    case OPENCV_IMGPROC_AUTO_THRESHOLD_TRIANGLE:
        opencv_flag = cv::THRESH_TRIANGLE;
        return true;
    default:
        return false;
    }
}

bool to_opencv_adaptive_threshold_method(
    int32_t method,
    int &opencv_method) noexcept
{
    switch (method) {
    case OPENCV_IMGPROC_ADAPTIVE_THRESHOLD_MEAN:
        opencv_method = cv::ADAPTIVE_THRESH_MEAN_C;
        return true;
    case OPENCV_IMGPROC_ADAPTIVE_THRESHOLD_GAUSSIAN:
        opencv_method = cv::ADAPTIVE_THRESH_GAUSSIAN_C;
        return true;
    default:
        return false;
    }
}

bool to_opencv_adaptive_threshold_mode(
    int32_t mode,
    int &opencv_mode) noexcept
{
    switch (mode) {
    case OPENCV_IMGPROC_THRESHOLD_BINARY:
        opencv_mode = cv::THRESH_BINARY;
        return true;
    case OPENCV_IMGPROC_THRESHOLD_BINARY_INVERSE:
        opencv_mode = cv::THRESH_BINARY_INV;
        return true;
    default:
        return false;
    }
}

bool to_opencv_contour_retrieval_mode(
    int32_t mode,
    int &opencv_mode) noexcept
{
    switch (mode) {
    case OPENCV_IMGPROC_CONTOUR_RETR_EXTERNAL:
        opencv_mode = cv::RETR_EXTERNAL;
        return true;
    case OPENCV_IMGPROC_CONTOUR_RETR_LIST:
        opencv_mode = cv::RETR_LIST;
        return true;
    case OPENCV_IMGPROC_CONTOUR_RETR_CCOMP:
        opencv_mode = cv::RETR_CCOMP;
        return true;
    case OPENCV_IMGPROC_CONTOUR_RETR_TREE:
        opencv_mode = cv::RETR_TREE;
        return true;
    default:
        return false;
    }
}

bool to_opencv_contour_approximation_mode(
    int32_t mode,
    int &opencv_mode) noexcept
{
    switch (mode) {
    case OPENCV_IMGPROC_CONTOUR_APPROX_NONE:
        opencv_mode = cv::CHAIN_APPROX_NONE;
        return true;
    case OPENCV_IMGPROC_CONTOUR_APPROX_SIMPLE:
        opencv_mode = cv::CHAIN_APPROX_SIMPLE;
        return true;
    case OPENCV_IMGPROC_CONTOUR_APPROX_TC89_L1:
        opencv_mode = cv::CHAIN_APPROX_TC89_L1;
        return true;
    case OPENCV_IMGPROC_CONTOUR_APPROX_TC89_KCOS:
        opencv_mode = cv::CHAIN_APPROX_TC89_KCOS;
        return true;
    default:
        return false;
    }
}

bool valid_contour_index(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index) noexcept
{
    return contour_index >= 0
        && static_cast<std::size_t>(contour_index) < result->contours.size();
}

bool fits_int32(std::size_t value) noexcept
{
    return value <= static_cast<std::size_t>(std::numeric_limits<int32_t>::max());
}

bool equalize_hist_pixel_count_fits_int(const cv::Mat &src) noexcept
{
    if (src.dims != 2 || src.rows <= 0 || src.cols <= 0) {
        return true;
    }

    const std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    const std::uint64_t max_int =
        static_cast<std::uint64_t>(std::numeric_limits<int>::max());

    return rows <= max_int / cols;
}

bool equalize_hist_views_overlap(const cv::Mat &src, const cv::Mat &dst) noexcept
{
    if (src.data == nullptr || dst.data == nullptr) {
        return false;
    }

    if (src.data == dst.data) {
        return true;
    }

    if (src.datastart == nullptr || src.datastart != dst.datastart) {
        return false;
    }

    if (src.dims != 2 || dst.dims != 2) {
        return true;
    }

    cv::Size whole_src;
    cv::Point origin_src;
    src.locateROI(whole_src, origin_src);

    cv::Size whole_dst;
    cv::Point origin_dst;
    dst.locateROI(whole_dst, origin_dst);

    const cv::Rect src_rect(origin_src, src.size());
    const cv::Rect dst_rect(origin_dst, dst.size());
    return (src_rect & dst_rect).area() > 0;
}

bool valid_filter_depth_combination(int src_depth, int32_t destination_depth)
    noexcept
{
    switch (src_depth) {
    case CV_8U:
        return destination_depth == OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_INT16
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT32
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT64;
    case CV_16U:
    case CV_16S:
        return destination_depth == OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT32
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT64;
    case CV_32F:
        return destination_depth == OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT32;
    case CV_64F:
        return destination_depth == OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH
            || destination_depth == OPENCV_IMGPROC_DERIVATIVE_FLOAT64;
    default:
        return false;
    }
}

bool mat_storage_overlaps(const cv::Mat &first, const cv::Mat &second) noexcept;

constexpr std::uint64_t pyramid_int_max =
    static_cast<std::uint64_t>(std::numeric_limits<int>::max());

// Natural-size pyrDown: final y = ceil(rows/2)-1, PD_SZ=5, sy0=-2,
// and k=4 maximize (y*2 - PD_SZ/2 + k - sy0) at 2*y+4.
constexpr bool pyramid_down_vertical_ring_fits(std::uint64_t rows) noexcept
{
    return rows > 0 && 2 * ((rows + 1) / 2 - 1) + 4 <= pyramid_int_max;
}

// pyrDown_'s border table visits x=0..PD_SZ+1 (6). Its width0 is
// min((cols-3)/2+1, ceil(cols/2)), with C++ truncation toward zero
// for cols=2. The largest x + width0*2 - PD_SZ/2 is 2*width0+4.
constexpr bool pyramid_down_horizontal_border_fits(std::uint64_t cols) noexcept
{
    if (cols == 0)
        return false;
    const std::uint64_t width0 = cols == 1 ? 0 :
        cols == 2 ? 1 : (cols - 3) / 2 + 1;
    return 2 * width0 + 4 <= pyramid_int_max;
}

static_assert(pyramid_down_vertical_ring_fits(pyramid_int_max - 3),
              "INT_MAX-3 rows fit the pyrDown vertical ring selector");
static_assert(!pyramid_down_vertical_ring_fits(pyramid_int_max - 2),
              "INT_MAX-2 rows overflow the pyrDown vertical ring selector");
static_assert(!pyramid_down_vertical_ring_fits(pyramid_int_max - 1),
              "INT_MAX-1 rows overflow the pyrDown vertical ring selector");
static_assert(pyramid_down_horizontal_border_fits(pyramid_int_max - 3),
              "INT_MAX-3 columns fit the pyrDown border table");
static_assert(!pyramid_down_horizontal_border_fits(pyramid_int_max - 2),
              "INT_MAX-2 columns overflow the pyrDown border table");
static_assert(!pyramid_down_horizontal_border_fits(pyramid_int_max - 1),
              "INT_MAX-1 columns overflow the pyrDown border table");

std::uint64_t pyramid_align_16(std::uint64_t value) noexcept
{
    return (value + 15) & ~std::uint64_t{15};
}

bool pyramid_ipp_type(const cv::Mat &src) noexcept
{
    return src.type() == CV_8UC1 || src.type() == CV_8UC3 ||
           src.type() == CV_32FC1 || src.type() == CV_32FC3;
}

// Number of distinct natural Gaussian levels, including level 0: halve each
// extent with (n+1)/2 until both reach 1. Extents are at most INT_MAX, so the
// result never exceeds 32.
int pyramid_distinct_level_count(std::uint64_t cols, std::uint64_t rows) noexcept
{
    int count = 1;
    while (cols > 1 || rows > 1) {
        cols = (cols + 1) / 2;
        rows = (rows + 1) / 2;
        ++count;
    }
    return count;
}

// OpenVX pyrDown in 4.1/4.10 accepts CV_8UC1, REPLICATE and natural size;
// createAddressing narrows Mat row steps to vx_int32. OpenCV 5.0 has no
// OpenVX path: retain this restriction as portable binding policy.
bool pyramid_down_may_use_openvx(int type, int border) noexcept
{
    return type == CV_8UC1 && border == cv::BORDER_REPLICATE;
}

// Scalar pyrDown_ arithmetic for one natural cols x rows -> ceil-half step.
// Shared by Pyramid_Down and every buildPyramid transition.
opencv_imgproc_status pyramid_down_extent_preflight(std::uint64_t cols,
                                                     std::uint64_t rows,
                                                     std::uint64_t cn)
{
    // ABI safety: pyrDown constructs Size((cols+1)/2, (rows+1)/2);
    // pyrDown_ doubles output extents and computes y*2+2 in its ring fill.
    // Its vertical ring selector reaches y*2+4; the horizontal border table
    // independently reaches x+width0*2-2 at x=6. Check both expressions.
    const std::uint64_t down_width = (cols + 1) / 2;
    const std::uint64_t down_height = (rows + 1) / 2;
    if (cols >= pyramid_int_max || rows >= pyramid_int_max ||
        down_width * 2 > pyramid_int_max ||
        down_height * 2 > pyramid_int_max ||
        !pyramid_down_vertical_ring_fits(rows) ||
        !pyramid_down_horizontal_border_fits(cols))
        return invalid_argument("pyrDown dimensions overflow native int arithmetic");

    const std::uint64_t source_width = cols * cn;
    const std::uint64_t scaled_width = down_width * cn;
    // ABI safety: pyrDown_ multiplies ssize.width and dsize.width by cn;
    // its aligned int bufstep then allocates AutoBuffer(bufstep*5+16).
    if (source_width > pyramid_int_max || scaled_width > pyramid_int_max ||
        pyramid_align_16(scaled_width) * 5 + 16 > pyramid_int_max)
        return invalid_argument("pyrDown channel width or ring buffer overflows native int");
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status pyramid_down_preflight(const cv::Mat &src,
                                              const cv::Mat &dst, int border)
{
    const std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    const std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cn = static_cast<std::uint64_t>(src.channels());
    const opencv_imgproc_status extent =
        pyramid_down_extent_preflight(cols, rows, cn);
    if (extent != OPENCV_IMGPROC_OK)
        return extent;
    const std::uint64_t down_width = (cols + 1) / 2;
    const std::uint64_t down_height = (rows + 1) / 2;
    const std::uint64_t scaled_width = down_width * cn;

    // 4.1/4.10 ipp_pyrdown's step casts are behind
    // dsz == Size(src.cols*2, src.rows*2), unreachable for natural downsize;
    // 5.0 has no direct ipp_pyrdown. buildPyramid's IPP path is covered by
    // build_pyramid_preflight.
    if (pyramid_down_may_use_openvx(src.type(), border)) {
        // ABI safety: native OpenVX row-step casts truncate size_t.
        const bool reused_destination =
            dst.size() == cv::Size(static_cast<int>(down_width),
                                   static_cast<int>(down_height)) &&
            dst.type() == src.type();
        if (src.step[0] > pyramid_int_max ||
            scaled_width * src.elemSize1() > pyramid_int_max ||
            (reused_destination && dst.step[0] > pyramid_int_max))
            return invalid_argument("pyrDown OpenVX byte step overflows signed int");
    }
    return OPENCV_IMGPROC_OK;
}

// Validates the whole native buildPyramid chain before any level is created.
// level_count has already been bounded to the distinct natural level count.
opencv_imgproc_status build_pyramid_preflight(const cv::Mat &src,
                                               int level_count, int border)
{
    std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cn = static_cast<std::uint64_t>(src.channels());
    const std::uint64_t element_size =
        static_cast<std::uint64_t>(src.elemSize());
    const bool openvx = pyramid_down_may_use_openvx(src.type(), border);
    // ipp_buildpyramid (identical in 4.1/4.10/5.0) runs for BORDER_DEFAULT
    // (REFLECT_101) on a non-submatrix CV_8UC1/8UC3/32FC1/32FC3 source; the
    // source handed to buildPyramid here is never a submatrix. It stores
    // gPyr->pStep[0] = (int)src.step and, per level, (int)dst.step of a
    // freshly created packed level. ippiPyramidInitAlloc receives
    // maxlevel + 1 == level_count (<= 32) and srcRoi from int cols/rows;
    // ippiGetPyramidDownROI only shrinks positive int extents. Stock builds
    // define IPP_DISABLE_PYRAMIDS_BUILD, but distributors may re-enable it.
    const bool ipp =
        border == cv::BORDER_REFLECT_101 && pyramid_ipp_type(src);

    // ABI safety: OpenVX createAddressing and ipp_buildpyramid narrow the
    // level-0 row step (a Region clone's packed step) to signed int.
    if ((openvx || ipp) && src.step[0] > pyramid_int_max)
        return invalid_argument(
            "buildPyramid source byte step overflows signed int");

    for (int level = 1; level < level_count; ++level) {
        // ABI safety: every transition is a native pyrDown with the same
        // signed pyrDown_ ring, border-table, and buffer arithmetic.
        const opencv_imgproc_status extent =
            pyramid_down_extent_preflight(cols, rows, cn);
        if (extent != OPENCV_IMGPROC_OK)
            return extent;
        cols = (cols + 1) / 2;
        rows = (rows + 1) / 2;
        // ABI safety: generated levels are packed, so their narrowed OpenVX
        // or IPP row step is cols * elemSize; level i is also the source of
        // transition i + 1.
        if ((openvx || ipp) && cols * element_size > pyramid_int_max)
            return invalid_argument(
                "buildPyramid level byte step overflows signed int");
    }
    return OPENCV_IMGPROC_OK;
}

// pyrUp to target_width x target_height; the natural call passes 2x extents.
opencv_imgproc_status pyramid_up_preflight(const cv::Mat &src,
                                            const cv::Mat &dst,
                                            std::uint64_t target_width,
                                            std::uint64_t target_height)
{
    const std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    const std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cn = static_cast<std::uint64_t>(src.channels());
    // ABI safety: pyrUp computes Size(src.cols*2, src.rows*2) for the natural
    // size; pyrUp_'s assert computes ssize.width*2 / ssize.height*2 for every
    // size; borderInterpolate(sy*2, ssize.height*2) and _dst.ptr(y*2) double
    // source rows. Target extents must be positive signed ints.
    if (cols * 2 > pyramid_int_max || rows * 2 > pyramid_int_max ||
        target_width == 0 || target_height == 0 ||
        target_width > pyramid_int_max || target_height > pyramid_int_max)
        return invalid_argument("pyrUp dimensions would overflow signed int");

    const std::uint64_t source_width = cols * cn;
    const std::uint64_t scaled_width = target_width * cn;
    const std::uint64_t raw_bufstep = (target_width + 1) * cn;
    // ABI safety: pyrUp_ multiplies both widths by cn, allocates its int
    // dtab(ssize.width*cn), and computes alignSize((dsize.width+1)*cn,16)
    // before casting bufstep to int and allocating bufstep*3+16, all before
    // its CV_Assert on the destination geometry.
    if (source_width > pyramid_int_max || scaled_width > pyramid_int_max ||
        raw_bufstep > pyramid_int_max ||
        pyramid_align_16(raw_bufstep) * 3 + 16 > pyramid_int_max)
        return invalid_argument("pyrUp channel width or ring buffer overflows native int");

    // IPP excludes unisolated Regions; the public call is never isolated.
    // 4.1/4.10/5.0 reach ipp_pyrup only for dsz == Size(cols*2, rows*2); odd
    // explicit targets use the (5.0: HAL, then) scalar pyrUp_ path.
    const bool exact_double =
        target_width == cols * 2 && target_height == rows * 2;
    if (exact_double && !src.isSubmatrix() && pyramid_ipp_type(src)) {
        // ABI safety: ipp_pyrup casts src.step and dst.step to signed int.
        const bool reused_destination =
            dst.size() == cv::Size(static_cast<int>(target_width),
                                   static_cast<int>(target_height)) &&
            dst.type() == src.type();
        if (src.step[0] > pyramid_int_max ||
            scaled_width * src.elemSize1() > pyramid_int_max ||
            (reused_destination && dst.step[0] > pyramid_int_max))
            return invalid_argument("pyrUp IPP byte step overflows signed int");
    }
    return OPENCV_IMGPROC_OK;
}

// ABI safety: OpenCV pyramid kernels access src as a 2-D image and use typed
// pointer arithmetic before fully rejecting empty or higher-dimensional Mats;
// HAL/dispatch selects typed neighborhood access from depth before rejecting
// unsupported depths.
opencv_imgproc_status validate_pyramid_source(const cv::Mat &src)
{
    if (src.empty()) {
        return invalid_argument("pyramid source must be nonempty");
    }

    if (src.dims != 2) {
        return invalid_argument("pyramid source must be two-dimensional");
    }

    const int depth = src.depth();
    if (depth != CV_8U && depth != CV_16U && depth != CV_16S
        && depth != CV_32F && depth != CV_64F) {
        return invalid_argument(
            "pyramid requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status resolve_pyramid_source_and_destination(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    const cv::Mat **src,
    cv::Mat **dst,
    const char *operation)
{
    opencv_core_status core_status =
        opencv_core_module_input_mat(source, src);

    if (core_status != OPENCV_CORE_OK || *src == nullptr) {
        return invalid_argument("invalid source Mat");
    }

    core_status = opencv_core_module_output_mat(destination, dst);

    if (core_status != OPENCV_CORE_OK || *dst == nullptr) {
        return invalid_argument("invalid destination Mat");
    }

    const opencv_imgproc_status source_status =
        validate_pyramid_source(**src);
    if (source_status != OPENCV_IMGPROC_OK) {
        return source_status;
    }

    // ABI safety: writing dst while reading the same buffer is undefined
    // for this size-changing pyramid operation.
    if (*src == *dst || mat_storage_overlaps(**src, **dst)) {
        char message[error_message_capacity];
        std::snprintf(
            message,
            error_message_capacity,
            "%s does not support aliased or overlapping source and destination storage",
            operation);
        return invalid_argument(message);
    }

    return OPENCV_IMGPROC_OK;
}

bool to_opencv_template_matching_method(
    int32_t method,
    int &opencv_method) noexcept
{
    switch (method) {
    case OPENCV_IMGPROC_TEMPLATE_SQDIFF:
        opencv_method = cv::TM_SQDIFF;
        return true;
    case OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED:
        opencv_method = cv::TM_SQDIFF_NORMED;
        return true;
    case OPENCV_IMGPROC_TEMPLATE_CCORR:
        opencv_method = cv::TM_CCORR;
        return true;
    case OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED:
        opencv_method = cv::TM_CCORR_NORMED;
        return true;
    case OPENCV_IMGPROC_TEMPLATE_CCOEFF:
        opencv_method = cv::TM_CCOEFF;
        return true;
    case OPENCV_IMGPROC_TEMPLATE_CCOEFF_NORMED:
        opencv_method = cv::TM_CCOEFF_NORMED;
        return true;
    default:
        return false;
    }
}

bool to_opencv_warp_interpolation(
    int32_t interpolation,
    int &opencv_interpolation) noexcept
{
    switch (interpolation) {
    case OPENCV_IMGPROC_WARP_INTER_NEAREST:
        opencv_interpolation = cv::INTER_NEAREST;
        return true;
    case OPENCV_IMGPROC_WARP_INTER_LINEAR:
        opencv_interpolation = cv::INTER_LINEAR;
        return true;
    default:
        return false;
    }
}

bool to_opencv_warp_mapping_flags(
    int32_t mapping,
    int interpolation,
    int &opencv_flags) noexcept
{
    switch (mapping) {
    case OPENCV_IMGPROC_WARP_MAPPING_SOURCE_TO_DESTINATION:
        opencv_flags = interpolation;
        return true;
    case OPENCV_IMGPROC_WARP_MAPPING_DESTINATION_TO_SOURCE:
        opencv_flags = interpolation | cv::WARP_INVERSE_MAP;
        return true;
    default:
        return false;
    }
}

bool to_opencv_warp_border(int32_t border, int &opencv_border) noexcept
{
    switch (border) {
    case OPENCV_IMGPROC_BORDER_CONSTANT:
        opencv_border = cv::BORDER_CONSTANT;
        return true;
    case OPENCV_IMGPROC_BORDER_REPLICATE:
        opencv_border = cv::BORDER_REPLICATE;
        return true;
    default:
        return false;
    }
}

bool floating_transform_is_finite(const cv::Mat &matrix) noexcept
{
    const int rows = matrix.rows;
    const int cols = matrix.cols;

    if (matrix.depth() == CV_32F) {
        for (int row = 0; row < rows; ++row) {
            const float *const coefficients = matrix.ptr<float>(row);
            for (int col = 0; col < cols; ++col) {
                if (!std::isfinite(coefficients[col])) {
                    return false;
                }
            }
        }
        return true;
    }

    for (int row = 0; row < rows; ++row) {
        const double *const coefficients = matrix.ptr<double>(row);
        for (int col = 0; col < cols; ++col) {
            if (!std::isfinite(coefficients[col])) {
                return false;
            }
        }
    }
    return true;
}

bool to_opencv_remap_interpolation(
    int32_t interpolation,
    int &opencv_interpolation) noexcept
{
    switch (interpolation) {
    case OPENCV_IMGPROC_INTER_NEAREST:
        opencv_interpolation = cv::INTER_NEAREST;
        return true;
    case OPENCV_IMGPROC_INTER_LINEAR:
        opencv_interpolation = cv::INTER_LINEAR;
        return true;
    case OPENCV_IMGPROC_INTER_CUBIC:
        opencv_interpolation = cv::INTER_CUBIC;
        return true;
    case OPENCV_IMGPROC_INTER_LANCZOS4:
        opencv_interpolation = cv::INTER_LANCZOS4;
        return true;
    default:
        return false;
    }
}

bool to_opencv_remap_border(int32_t border, int &opencv_border) noexcept
{
    switch (border) {
    case OPENCV_IMGPROC_BORDER_CONSTANT:
        opencv_border = cv::BORDER_CONSTANT;
        return true;
    case OPENCV_IMGPROC_BORDER_REPLICATE:
        opencv_border = cv::BORDER_REPLICATE;
        return true;
    case OPENCV_IMGPROC_BORDER_REFLECT:
        opencv_border = cv::BORDER_REFLECT;
        return true;
    case OPENCV_IMGPROC_BORDER_REFLECT_101:
        opencv_border = cv::BORDER_REFLECT_101;
        return true;
    case OPENCV_IMGPROC_BORDER_WRAP:
        opencv_border = cv::BORDER_WRAP;
        return true;
    default:
        return false;
    }
}

// ABI safety: RemapInvoker rounds unscaled Float32 coordinates for nearest
// interpolation, and rounds coordinates multiplied in Float32 by 32 for
// interpolated modes. Keep either operand strictly inside the signed-int
// domain before cvRound, saturate_cast<short>, or SIMD v_round can see it.
bool float32_map_coordinates_safe(const cv::Mat &matrix, bool nearest) noexcept
{
    const int rows = matrix.rows;
    // ABI safety: map width < 32767 makes 2 * cols fit int for C2 rows.
    const int cols = matrix.cols * matrix.channels();

    for (int row = 0; row < rows; ++row) {
        const float *const coordinates = matrix.ptr<float>(row);
        for (int col = 0; col < cols; ++col) {
            const float value = coordinates[col];
            if (!std::isfinite(value)) {
                return false;
            }
            const float rounded_operand = nearest ? value : value * 32.0f;
            // +/-2^31 is exactly representable in Float32; exclude both
            // endpoints, allowing room for the platform rounding operation.
            if (!std::isfinite(rounded_operand)
                || !(rounded_operand > -2147483648.0f
                     && rounded_operand < 2147483648.0f)) {
                return false;
            }
        }
    }
    return true;
}

// ABI safety: bound the Float32 operand rounded by RemapInvoker (including
// the interpolated Float32 multiplication) before warpPolar creates its maps.
// The extra margin covers Float32 map construction and transcendental error.
bool polar_coordinate_bound_safe(double bound, bool nearest) noexcept
{
    constexpr double limit = 2147483648.0;
    const double operand = nearest ? bound : bound * 32.0;
    return std::isfinite(bound) && bound >= 0 &&
           bound < static_cast<double>(std::numeric_limits<float>::max()) &&
           std::isfinite(operand) && operand < limit - 1024.0;
}

// ABI safety: copyMakeBorder adds two rows before inverse remap checks its
// signed 16-bit source geometry. Avoid addition in the signed-int domain.
constexpr bool polar_inverse_rows_safe(int rows) noexcept
{
    return rows > 0 && rows <= 32764;
}
static_assert(polar_inverse_rows_safe(32764) && !polar_inverse_rows_safe(32765),
              "inverse wrap padding must leave remap rows below 32767");

// In OpenCV 4.1/4.10 these are exactly the separate-map, interpolation,
// border and source types dispatched through IPPRemapInvoker. OpenCV 5.0
// has no such IPP remap invoker, but retaining the portable guard is safe.
bool remap_may_use_ipp(int type, int interpolation, int border) noexcept
{
    if (border != cv::BORDER_CONSTANT ||
        (interpolation != cv::INTER_NEAREST &&
         interpolation != cv::INTER_LINEAR &&
         interpolation != cv::INTER_CUBIC))
        return false;

    switch (type) {
    case CV_8UC1: case CV_8UC3: case CV_8UC4:
    case CV_16UC1: case CV_16UC3: case CV_16UC4:
    case CV_32FC1: case CV_32FC3: case CV_32FC4:
        return true;
    default:
        return false;
    }
}

bool remap_uint8_linear_simd_stride_safe(const cv::Mat &src,
                                          int interpolation) noexcept
{
    if (interpolation != cv::INTER_LINEAR ||
        (src.type() != CV_8UC1 && src.type() != CV_8UC3 &&
         src.type() != CV_8UC4))
        return true;

    // ABI safety: RemapVec_8u narrows _src.step from size_t to int before
    // checking the SIMD stride limit in OpenCV 4.1, 4.10 and 5.0.
    if (src.step[0] > static_cast<size_t>(std::numeric_limits<int>::max()))
        return false;

    // ABI safety: OpenCV 4.1 admits sstep == 0x8000 and later forms
    // sstep << 16; reject that exact portable-baseline boundary. Values
    // above 0x8000 (but within int) take the scalar fallback instead.
    return src.step[0] != static_cast<size_t>(0x8000);
}

// ABI safety: OpenCV 4.1/4.10 use cvRound(scale * XY_ONE), byte-offset
// Hershey glyph coordinates (at most 173 from 'R'), fixed-point products,
// accumulated view_x/view_y and getTextSize accumulation/cvRound.
// OpenCV 5 uses hersheyToTruetype cvRound(100*scale/sf), weight*65536,
// int(len), UTF-8 -> UTF-32 buffers, glyph bitmap sizes and advance conversion;
// its pen, linegap, glyph coordinates and bounding-box additions/subtractions
// use int. This intentionally conservative bound limits all of those paths,
// including multiline vertical advance, and leaves room at both ends of int.
bool safe_text_geometry(int32_t length, double scale, int32_t thickness,
                        int64_t *excursion = nullptr) noexcept
{
    constexpr double limit = 1000000.0;
    const double extent = static_cast<double>(length) * scale * 512.0 + thickness;
    const bool safe = length >= 0 && thickness > 0 && thickness <= 32767 &&
        std::isfinite(scale) && scale > 0 &&
        scale * 65536.0 <= limit &&
        extent < limit;
    if (safe && excursion)
        *excursion = static_cast<int64_t>(std::ceil(extent + scale * 512.0 + 64.0));
    return safe;
}

bool valid_hershey(int32_t font) noexcept
{
    return font >= 0 && font <= 7;
}

bool drawing_image(const cv::Mat &image, const char **message) noexcept
{
    if (image.dims != 2) {
        // ABI safety: drawing addresses the image through rows and cols.
        // A higher-dimensional Mat makes those two sizes not describe the
        // buffer being written.
        *message = "drawing image must be two-dimensional";
        return false;
    }

    switch (image.depth()) {
    case CV_8U:
    case CV_16U:
    case CV_16S:
    case CV_32F:
    case CV_64F:
        break;
    default:
        // ABI safety: scalarToRawData rejects unsupported depths only after
        // the drawing raster has begun. Restrict the depth before that write.
        *message = "drawing image depth is not supported";
        return false;
    }

    const int channels = image.channels();
    if (channels < 1 || channels > 4) {
        // ABI safety: the drawing color buffer is four components. More than
        // four channels reads past that buffer.
        *message = "drawing image must have 1 to 4 channels";
        return false;
    }

    return true;
}

bool text_image(const cv::Mat &image, const char **message) noexcept
{
    // ABI safety: OpenCV 5's renderer assumes byte pixels with 1, 3 or 4
    // components when it writes glyph bitmaps; reject other layouts first.
    if (image.empty() || image.dims != 2 || image.depth() != CV_8U ||
        (image.channels() != 1 && image.channels() != 3 && image.channels() != 4)) {
        *message = "text image must be nonempty 2-D UInt8 C1, C3 or C4";
        return false;
    }
    return true;
}

bool drawing_color(
    const cv::Mat &image,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    cv::Scalar &color,
    const char **message) noexcept
{
    const double components[4] = {color_0, color_1, color_2, color_3};
    const int channels = image.channels();

    for (int index = 0; index < channels; ++index) {
        if (!std::isfinite(components[index])) {
            // ABI safety: scalarToRawData saturates nonfinite values into
            // integer pixels instead of rejecting them, producing a partially
            // initialized color.
            *message = "drawing color components in use must be finite";
            return false;
        }
    }

    color = cv::Scalar(color_0, color_1, color_2, color_3);
    return true;
}

bool drawing_line_style(
    int32_t line_style,
    const cv::Mat &image,
    int &opencv_line,
    const char **message) noexcept
{
    switch (line_style) {
    case OPENCV_IMGPROC_LINE_4:
        opencv_line = cv::LINE_4;
        return true;
    case OPENCV_IMGPROC_LINE_8:
        opencv_line = cv::LINE_8;
        return true;
    case OPENCV_IMGPROC_LINE_AA:
        if (image.depth() != CV_8U) {
            // ABI safety: OpenCV silently replaces LINE_AA with LINE_8 for
            // non-8-bit images, so the requested antialiased write does not
            // occur. Reject it before that substitution.
            *message = "antialiased drawing requires a UInt8 image";
            return false;
        }
        opencv_line = cv::LINE_AA;
        return true;
    default:
        *message = "unsupported drawing line style";
        return false;
    }
}

bool drawing_thickness(
    int32_t filled,
    int32_t thickness,
    int &opencv_thickness,
    const char **message) noexcept
{
    if (filled == OPENCV_IMGPROC_DRAW_FILLED) {
        opencv_thickness = cv::FILLED;
        return true;
    }

    if (filled != OPENCV_IMGPROC_DRAW_OUTLINE) {
        *message = "unsupported drawing fill selector";
        return false;
    }

    if (thickness <= 0 || thickness > 32767) {
        // ABI safety: OpenCV drawing uses thickness in signed raster offsets.
        // A nonpositive or oversized thickness overflows those offsets.
        *message = "drawing thickness must be from 1 through 32767";
        return false;
    }

    opencv_thickness = static_cast<int>(thickness);
    return true;
}

bool drawing_angles(
    double angle,
    double start_angle,
    double end_angle,
    const char **message) noexcept
{
    if (!std::isfinite(angle)
        || !std::isfinite(start_angle)
        || !std::isfinite(end_angle)) {
        // ABI safety: ellipse rounding of a nonfinite angle produces an
        // indeterminate integer before the raster is clipped.
        *message = "drawing ellipse angles must be finite";
        return false;
    }

    return true;
}

// Inclusive far corner of a positive-extent rectangle, saturated to the
// signed OpenCV point domain. OpenCV 4.1's Rect overload computes
// br() as (x + width, y + height) with signed int arithmetic before
// clipping, so an off-image origin plus a large positive extent overflows.
// The two-point rectangle overload receives already-saturated endpoints.
int saturated_rectangle_far(int32_t origin, int32_t extent) noexcept
{
    const int64_t far =
        static_cast<int64_t>(origin) + static_cast<int64_t>(extent) - 1;
    if (far > static_cast<int64_t>(std::numeric_limits<int>::max())) {
        return std::numeric_limits<int>::max();
    }
    if (far < static_cast<int64_t>(std::numeric_limits<int>::min())) {
        return std::numeric_limits<int>::min();
    }
    return static_cast<int>(far);
}

std::vector<cv::Point> native_drawing_points(
    const opencv_imgproc_point_i32 *points,
    int32_t point_count)
{
    std::vector<cv::Point> native;
    native.reserve(static_cast<std::size_t>(point_count));
    for (int32_t index = 0; index < point_count; ++index) {
        native.emplace_back(
            static_cast<int>(points[index].x),
            static_cast<int>(points[index].y));
    }
    return native;
}

// Hough preflight. OpenCV 4.1, 4.10, and 5.0 hough.cpp derive accumulator
// geometry with signed int arithmetic and cvRound/cvFloor/cvCeil before any
// validation. Each guard mirrors a concrete native expression so a raw C ABI
// caller cannot cause signed overflow, an unrepresentable floating-to-integer
// or double-to-float conversion, or a wrapped/negative buffer size.

constexpr std::int64_t hough_int_max = std::numeric_limits<int>::max();

bool representable_binary32(double value) noexcept
{
    return std::isfinite(value)
        && std::fabs(value) <= static_cast<double>(
               std::numeric_limits<float>::max());
}

// ABI safety: shared raw Hough source validation, run before cloning,
// cv::countNonZero, and every geometry preflight below. rows and cols are -1
// for N-D Mats and would feed the native signed geometry arithmetic; the
// line transforms read the snapshot as raw uchar rows and HoughCircles runs
// Sobel on it, so the element type must be exactly CV_8UC1 for that
// arithmetic to model the native code. HoughLinesStandard indexes
// image[i * step + j], HoughLinesProbabilistic indexes mdata0[i * width + j],
// and the circle accumulator multiplies cols by a row count, all in int on a
// continuous snapshot, so rows * cols must fit int.
bool hough_source_valid(
    const cv::Mat &src, std::int64_t &rows, std::int64_t &cols,
    const char **message) noexcept
{
    if (src.empty()) {
        *message = "Hough source must be nonempty";
        return false;
    }
    if (src.dims != 2 || src.rows <= 0 || src.cols <= 0) {
        *message = "Hough source must be two-dimensional";
        return false;
    }
    if (src.depth() != CV_8U) {
        *message = "Hough source must have UInt8 depth";
        return false;
    }
    if (src.channels() != 1) {
        *message = "Hough source must have exactly one channel";
        return false;
    }
    rows = src.rows;
    cols = src.cols;
    if (rows * cols > hough_int_max) {
        *message = "Hough source pixel count exceeds native int range";
        return false;
    }
    return true;
}

// ABI safety: both line transforms narrow rho to float, form irho = 1 / rho,
// evaluate (width + height) * 2 + 1 in int, and allocate
// numrho = cvRound(that / rho) (+2) accumulator columns. numrho is computed
// here exactly as the native float expression computes it.
bool hough_numrho(
    std::int64_t rows, std::int64_t cols, double rho,
    std::int64_t &numrho, const char **message) noexcept
{
    const std::int64_t span = (rows + cols) * 2 + 1;
    if (span > hough_int_max) {
        *message = "Hough source rows + columns exceed native int range";
        return false;
    }
    if (!representable_binary32(rho)) {
        *message = "Hough distance resolution must be a finite binary32";
        return false;
    }
    const float native_rho = static_cast<float>(rho);
    if (!(native_rho > 0.0f) || !std::isfinite(1.0f / native_rho)) {
        *message = "Hough distance resolution must be positive in binary32";
        return false;
    }
    const float quotient =
        static_cast<float>(static_cast<int>(span)) / native_rho;
    // 2147483520 is the largest binary32 value below 2^31; cvRound of any
    // larger quotient is not representable, and numrho + 2 must still fit.
    if (!(quotient <= 2147483520.0f)) {
        *message = "Hough distance resolution yields too many rho bins";
        return false;
    }
    numrho = static_cast<std::int64_t>(
        std::nearbyint(static_cast<double>(quotient)));
    return true;
}

// ABI safety: each nonzero pixel (j, i) votes into accumulator column
// cvRound(j * tabCos[n] + i * tabSin[n]) + (numrho - 1) / 2, where the tables
// hold cos/sin scaled by irho. That column is not clamped. The magnitude of
// the rounded term is at most hypot(cols - 1, rows - 1) * irho, widened here
// by a relative margin for binary32 rounding. HoughLinesStandard pads each
// row by one column (low_slack = high_slack = 1); HoughLinesProbabilistic has
// no padding, so an overshoot there writes outside its accumulator, and
// numrho == 0 leaves the accumulator empty.
bool hough_vote_columns_fit(
    std::int64_t rows, std::int64_t cols, double rho, std::int64_t numrho,
    std::int64_t slack, const char **message) noexcept
{
    if (rows == 0 || cols == 0) {
        return true;
    }
    const float irho = 1.0f / static_cast<float>(rho);
    const double extent = std::hypot(
        static_cast<double>(cols - 1), static_cast<double>(rows - 1));
    const double magnitude = extent * static_cast<double>(irho);
    const std::int64_t reach = static_cast<std::int64_t>(
        std::floor(magnitude * (1.0 + 1.0e-6) + 0.5));
    const std::int64_t offset = (numrho - 1) / 2;
    if (offset - reach < -slack || offset + reach > numrho - 1 + slack) {
        *message =
            "Hough distance resolution is too coarse for the accumulator";
        return false;
    }
    return true;
}

// ABI safety: theta is narrowed to float. OpenCV 4.1 uses
// numangle = cvRound(range / theta); 4.10 and 5.0 use
// cvFloor(range / theta) + 1; both then allocate numangle + 2 rows. The
// returned numangle bounds every version.
bool hough_numangle(
    double range, double theta, std::int64_t &numangle,
    const char **message) noexcept
{
    if (!representable_binary32(theta)) {
        *message = "Hough angle resolution must be a finite binary32";
        return false;
    }
    const float native_theta = static_cast<float>(theta);
    if (!(native_theta > 0.0f)) {
        *message = "Hough angle resolution must be positive in binary32";
        return false;
    }
    const double quotient =
        std::max(range, 0.0) / static_cast<double>(native_theta);
    if (!(quotient <= static_cast<double>(hough_int_max - 4))) {
        *message = "Hough angle resolution yields too many angle bins";
        return false;
    }
    numangle = static_cast<std::int64_t>(std::floor(quotient)) + 2;
    return true;
}

// rows and cols come from hough_source_valid; nonzero_count is
// cv::countNonZero of the continuous snapshot that OpenCV will receive.
bool hough_lines_preflight(
    std::int64_t rows, std::int64_t cols, std::int64_t nonzero_count,
    double rho, double theta, int32_t threshold,
    double min_theta, double max_theta, const char **message) noexcept
{
    std::int64_t numrho = 0;
    std::int64_t numangle = 0;
    // ABI safety: the standard-Hough IPP branch divides by threshold
    // (nz * numangle / threshold), so zero would divide by zero whenever
    // OpenCV is built with IPP Hough enabled.
    if (threshold <= 0) {
        *message = "Hough line threshold must be positive";
        return false;
    }
    if (!hough_numrho(rows, cols, rho, numrho, message)) {
        return false;
    }
    // ABI safety: min_theta is narrowed to float for the trig table and the
    // angle difference feeds cvRound/cvFloor.
    if (!representable_binary32(min_theta)
        || !representable_binary32(max_theta)) {
        *message = "Hough angle bounds must be finite binary32 values";
        return false;
    }
    if (!hough_numangle(max_theta - min_theta, theta, numangle, message)
        || !hough_vote_columns_fit(rows, cols, rho, numrho, 1, message)) {
        return false;
    }
    // ABI safety: HoughLinesStandard allocates (numangle + 2) x (numrho + 2)
    // ints and indexes it with int (n + 1) * (numrho + 2) + r + 1.
    if (numangle + 2 > hough_int_max / (numrho + 2)) {
        *message = "Hough line accumulator exceeds native int indexing";
        return false;
    }
    // ABI safety: OpenCV 4.1.0, 4.10.0, and 5.0.0 HoughLinesStandard IPP
    // branch evaluates
    //     int nz = countNonZero(img);
    //     int ipp_linesMax = std::min(linesMax, nz*numangle/threshold);
    // with nz * numangle in signed int. The accumulator checks above do not
    // bound that product. numangle here is an upper bound of the native
    // cvRound / computeNumangle value in every version, so rejecting
    // nonzero_count > INT_MAX / numangle covers all of them without ever
    // forming the product. The guard is applied whether or not this OpenCV
    // build enables IPP, so safety does not depend on optional acceleration.
    if (nonzero_count > hough_int_max / numangle) {
        *message =
            "Hough nonzero pixel count times angle bins exceeds native int";
        return false;
    }
    return true;
}

bool hough_segments_preflight(
    std::int64_t rows, std::int64_t cols, double rho, double theta,
    int32_t threshold, int32_t min_line_length, int32_t max_line_gap,
    const char **message) noexcept
{
    std::int64_t numrho = 0;
    std::int64_t numangle = 0;
    // ABI safety: the native vote loop starts from max_val = threshold - 1,
    // which overflows at INT_MIN; the public contract requires a positive
    // threshold, so every nonpositive value is rejected here.
    if (threshold <= 0) {
        *message = "Hough segment threshold must be positive";
        return false;
    }
    // ABI safety: HoughLinesP passes these to cvRound and compares segment
    // extents and gap counters against them in int; negative values have no
    // defined meaning in the modelled walk.
    if (min_line_length < 0 || max_line_gap < 0) {
        *message = "Hough segment length and gap must be nonnegative";
        return false;
    }
    if (!hough_numrho(rows, cols, rho, numrho, message)
        || !hough_numangle(CV_PI, theta, numangle, message)
        || !hough_vote_columns_fit(rows, cols, rho, numrho, 0, message)) {
        return false;
    }
    // ABI safety: HoughLinesProbabilistic sizes trigtab(numangle * 2) and
    // walks an accumulator with adata += numrho for each of numangle rows;
    // its IPP branch also computes numangle * numrho in int.
    if (numangle > hough_int_max / 2
        || (numrho > 0 && numangle > hough_int_max / numrho)) {
        *message = "Hough segment accumulator exceeds native int sizing";
        return false;
    }
    // ABI safety: OpenCV 4.1 and 4.10 walk segments in int 16.16 fixed point,
    // (coordinate << 16) + (1 << 15), stepping one pixel past the border.
    if ((std::max(rows, cols) + 2) * 65536 > hough_int_max) {
        *message =
            "Hough segment source dimension exceeds native fixed-point range";
        return false;
    }
    return true;
}

bool hough_circles_preflight(
    std::int64_t rows, std::int64_t cols, double dp, double min_dist,
    int32_t canny_threshold, int32_t accumulator_threshold,
    int32_t radius_mode, int32_t min_radius, int32_t max_radius,
    const char **message) noexcept
{
    // ABI safety: the raw ABI takes integer thresholds that OpenCV converts
    // with cvRound(param1/param2) and uses as Canny(max(1, t / 2), t) and as
    // the center/radius vote threshold. The public contract requires both
    // to be positive, and raw callers must not reach those conversions with
    // values the modelled arithmetic does not cover.
    if (canny_threshold <= 0) {
        *message = "Hough Canny threshold must be positive";
        return false;
    }
    if (accumulator_threshold <= 0) {
        *message = "Hough accumulator threshold must be positive";
        return false;
    }
    // ABI safety: HoughCirclesAccumInvoker allocates (arows + 2) x
    // (acols + 2) ints with arows <= rows and acols <= cols for dp >= 1, then
    // indexes it with int y2 * astep + x2, and HoughCirclesFindCentersInvoker
    // uses int base = y * acols + x and base +/- acols. rows * cols fitting
    // int does not bound that padded product (for example 46340 x 46340).
    if ((rows + 2) > hough_int_max / (cols + 2)) {
        *message = "Hough circle accumulator exceeds native int indexing";
        return false;
    }
    // ABI safety: dp is narrowed to float and 1 / dp drives cvCeil/cvRound of
    // the accumulator geometry. NaN passes OpenCV's dp <= 0 check. Requiring
    // dp >= 1 makes the geometry below identical to the native geometry,
    // since OpenCV clamps smaller values to 1.
    if (!representable_binary32(dp) || !(dp >= 1.0)) {
        *message = "Hough accumulator scale must be finite and at least 1";
        return false;
    }
    // ABI safety: minDist is narrowed to float and squared; NaN passes
    // OpenCV's minDist <= 0 check.
    if (!representable_binary32(min_dist)
        || !(static_cast<float>(min_dist) > 0.0f)) {
        *message = "Hough minimum center distance must be positive and finite";
        return false;
    }
    // ABI safety: a negative native maxRadius selects centers-only output
    // (a different result layout), and maxRadius <= minRadius is rewritten
    // to minRadius + 2, which overflows at INT_MAX.
    if (min_radius < 0) {
        *message = "Hough minimum radius must be nonnegative";
        return false;
    }
    std::int64_t effective_max = 0;
    const bool centers_only =
        radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_CENTERS_ONLY;
    if (radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC
        || centers_only) {
        // ABI safety: centers-only privately passes maxRadius = -1; a raw
        // caller cannot choose the sentinel or another value for it.
        if (max_radius != 0) {
            *message = centers_only
                ? "centers-only Hough radius mode requires max_radius 0"
                : "automatic Hough radius mode requires max_radius 0";
            return false;
        }
        // OpenCV 4.1/4.10/5.0 HoughCircles rewrite maxRadius <= 0 (including
        // the centers-only -1, after recording centersOnly) to
        // max(rows, cols), which bounds the accumulator voting walk.
        effective_max = std::max(rows, cols);
    } else if (radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_EXPLICIT) {
        if (max_radius <= min_radius) {
            *message = "explicit Hough max_radius must exceed min_radius";
            return false;
        }
        effective_max = max_radius;
    } else {
        *message = "unsupported Hough radius mode";
        return false;
    }
    // ABI safety: HoughCirclesGradient evaluates maxRadius * maxRadius in int
    // and filterCircles evaluates maxRadius + 1. Both occur only in the
    // radius-estimation branch; with centersOnly, OpenCV 4.1, 4.10, and 5.0
    // call GetCircleCenters instead and never evaluate them, so that mode
    // is not rejected for them.
    if (!centers_only && effective_max > 46340) {
        *message = "Hough maximum radius exceeds native int arithmetic";
        return false;
    }
    // ABI safety: the accumulator invoker forms x0 = cvRound(x / dp * 1024)
    // and then x0 + minRadius * sx (|sx| <= 1024) in int before its first
    // bounds check, then advances one step past the accumulator border.
    // HoughCirclesAccumInvoker runs in every mode, including centers-only.
    if ((std::max(rows, cols) + static_cast<std::int64_t>(min_radius) + 2)
            * 1024 > hough_int_max) {
        *message = "Hough circle geometry exceeds native fixed-point range";
        return false;
    }
    if (centers_only) {
        // The nBins histogram below belongs to
        // HoughCircleEstimateRadiusInvoker, which centers-only never
        // constructs, and GetCircleCenters only decodes accumulator
        // indices already bounded by the padded-accumulator check above.
        return true;
    }
    // ABI safety: radius estimation allocates AutoBuffer<int>(nBins) with
    // nBins = cvRound((maxRadius - minRadius) / dp * 10) and then writes
    // bins[max(0, min(nBins - 1, ...))]; nBins < 1 writes out of bounds.
    const float native_dp = std::max(static_cast<float>(dp), 1.0f);
    const float bins =
        static_cast<float>(static_cast<int>(effective_max - min_radius))
        / native_dp * 10;
    if (cvRound(bins) < 1) {
        *message = "Hough radius range is empty at this accumulator scale";
        return false;
    }
    return true;
}

// HoughLinesPointSet preflight. OpenCV 4.1.0, 4.10.0, and 5.0.0 compute
//     float irho     = 1 / (float)rho_step;
//     float irho_min = (float)min_rho * irho;
//     numangle = cvRound((max_theta - min_theta) / theta_step)       (4.1)
//              = computeNumangle(min_theta, max_theta, theta_step)  (4.10/5.0)
//     numrho   = cvRound((max_rho - min_rho + 1) / rho_step);
//     Mat::zeros(numangle + 2, numrho + 2, CV_32SC1);
// and then, for every point and angle bin n,
//     r = cvRound(x * tabCos[n] + y * tabSin[n] - irho_min);
//     accum[(n + 1) * (numrho + 2) + r + 1]++;
// OpenCV 4.10 and 5.0 guard that write with r >= 0 && r <= numrho. OpenCV
// 4.1 has NO range check, so a vote column outside the accumulator writes
// out of bounds there. NaN passes OpenCV's own max > min and step > 0
// checks, and cvRound of NaN, infinity, or an out-of-int operand is
// undefined.

struct point_set_geometry {
    float irho;
    float irho_min;
    std::int64_t numangle_bound;  // >= native numangle in every version
    std::int64_t numrho_low;      // <= native numrho under any cvRound tie
};

bool hough_point_set_geometry(
    double min_rho, double max_rho, double rho_step,
    double min_theta, double max_theta, double theta_step,
    point_set_geometry &geometry, const char **message) noexcept
{
    // ABI safety: rho/angle bounds and steps are narrowed to float and their
    // quotients feed cvRound/cvFloor before OpenCV validates anything.
    if (!representable_binary32(min_rho) || !representable_binary32(max_rho)
        || !representable_binary32(rho_step)
        || !representable_binary32(min_theta)
        || !representable_binary32(max_theta)
        || !representable_binary32(theta_step)) {
        *message = "Hough point-set bounds and steps must be finite binary32";
        return false;
    }
    // ABI safety: the shim's own bin model below divides by numrho + 2 and
    // floors the angle quotient; both assume positive spans. (OpenCV
    // rejects these too, but NaN reached it before the checks above.)
    if (!(min_rho < max_rho) || !(min_theta < max_theta)) {
        *message = "Hough point-set maximum must exceed minimum";
        return false;
    }
    const float native_rho_step = static_cast<float>(rho_step);
    const float irho = 1.0f / native_rho_step;
    if (!(native_rho_step > 0.0f) || !std::isfinite(irho)) {
        *message = "Hough point-set rho step must be positive in binary32";
        return false;
    }
    const float irho_min = static_cast<float>(min_rho) * irho;
    if (!std::isfinite(irho_min)) {
        *message = "Hough point-set minimum rho overflows binary32 arithmetic";
        return false;
    }
    if (!(static_cast<float>(theta_step) > 0.0f)) {
        *message = "Hough point-set angle step must be positive in binary32";
        return false;
    }
    // ABI safety: 4.1 uses cvRound(q) and 4.10/5.0 cvFloor(q) + 1 (minus at
    // most one), in int before any validation; floor(q) + 1 bounds every
    // version. (Zero bins are memory-safe natively; requiring at least one
    // bin is public Ada policy and is not repeated here.)
    const double angle_quotient = (max_theta - min_theta) / theta_step;
    if (!(angle_quotient <= static_cast<double>(hough_int_max - 4))) {
        *message = "Hough point-set angle step yields too many angle bins";
        return false;
    }
    const std::int64_t numangle_bound =
        static_cast<std::int64_t>(std::floor(angle_quotient)) + 1;
    // ABI safety: numrho = cvRound(q) in int; q beyond int is undefined.
    // Ties are modelled both ways (half-even lrint and half-away fallback
    // cvRound): the smaller value bounds vote columns, the larger bounds the
    // allocation. A zero-bin numrho is memory-safe natively (every vote must
    // then round to r = 0, the padded column); requiring at least one
    // usable bin is public Ada policy and is not repeated here.
    const double rho_quotient = (max_rho - min_rho + 1.0) / rho_step;
    if (!(rho_quotient <= static_cast<double>(hough_int_max - 4))) {
        *message = "Hough point-set rho step yields too many rho bins";
        return false;
    }
    const std::int64_t numrho_low =
        static_cast<std::int64_t>(std::ceil(rho_quotient - 0.5));
    const std::int64_t numrho_high =
        static_cast<std::int64_t>(std::floor(rho_quotient + 0.5));
    // ABI safety: the accumulator holds (numangle + 2) * (numrho + 2) ints
    // addressed by the signed int index (n + 1) * (numrho + 2) + r + 1.
    // Checked in widened arithmetic without forming the product.
    if (numangle_bound + 2 > hough_int_max / (numrho_high + 2)) {
        *message = "Hough point-set accumulator exceeds native int indexing";
        return false;
    }
    geometry.irho = irho;
    geometry.irho_min = irho_min;
    geometry.numangle_bound = numangle_bound;
    geometry.numrho_low = numrho_low;
    return true;
}

// ABI safety: OpenCV 4.1 HoughLinesPointSet increments
// accum[(n + 1) * (numrho + 2) + r + 1] with no check on r. This emulates
// the native binary32 vote column of every point for every angle bin any
// supported version can visit (numangle_bound) and requires
// 0 <= r <= numrho, the range 4.10/5.0 accept. On an accepted request 4.1
// never writes outside its accumulator, and no version drops a vote.
//
// The running angle and trig tables follow createTrigTable exactly:
//     float ang = (float)min_theta; ... ang += (float)theta_step;
//     tab[n] = (float)(sin((double)ang) * irho);
// The vote operand x * tabCos + y * tabSin - irho_min is then evaluated
// exactly in double (every binary32 product is exact there) and widened by
// magnitude * 2^-20. That covers the three binary32 roundings of any
// evaluation order or FMA contraction (at most 3 * 2^-24 relative) plus a
// one-ulp libm difference in each table value (2^-23 relative). The bound
// requires the operand to lie strictly inside (-0.5, numrho + 0.5), so
// cvRound yields r in [0, numrho] under either tie rule and is never
// applied to an out-of-int operand. cvRound itself is never called here.
bool hough_point_set_votes_fit(
    const opencv_imgproc_point_f32 *points, int32_t point_count,
    double min_theta, double theta_step, const point_set_geometry &geometry,
    const char **message) noexcept
{
    if (point_count == 0) {
        return true;
    }
    // Every binary32 intermediate stays finite when the sum of absolute
    // terms is at most 2^100, far below FLT_MAX (about 2^128).
    const double finite_limit = std::ldexp(1.0, 100);
    const double error_scale = std::ldexp(1.0, -20);
    const double high_limit = static_cast<double>(geometry.numrho_low) + 0.5;
    const double irho = static_cast<double>(geometry.irho);
    const double irho_min = static_cast<double>(geometry.irho_min);
    const float angle_step = static_cast<float>(theta_step);

    float angle = static_cast<float>(min_theta);
    for (std::int64_t n = 0; n < geometry.numangle_bound;
         ++n, angle += angle_step) {
        const double table_sin = static_cast<double>(static_cast<float>(
            std::sin(static_cast<double>(angle)) * irho));
        const double table_cos = static_cast<double>(static_cast<float>(
            std::cos(static_cast<double>(angle)) * irho));
        for (int32_t index = 0; index < point_count; ++index) {
            const double term_x =
                static_cast<double>(points[index].x) * table_cos;
            const double term_y =
                static_cast<double>(points[index].y) * table_sin;
            const double magnitude =
                std::fabs(term_x) + std::fabs(term_y) + std::fabs(irho_min);
            if (!(magnitude <= finite_limit)) {
                *message =
                    "Hough point-set vote arithmetic exceeds binary32 range";
                return false;
            }
            const double operand = term_x + term_y - irho_min;
            const double error = magnitude * error_scale;
            if (!(operand - error > -0.5) || !(operand + error < high_limit)) {
                *message =
                    "Hough point-set rho range does not contain every vote";
                return false;
            }
        }
    }
    return true;
}

bool fits_capacity(int32_t capacity, std::size_t count) noexcept
{
    return capacity >= 0 && static_cast<std::size_t>(capacity) >= count;
}

// Segmentation helpers.

constexpr std::uint64_t native_int_max =
    static_cast<std::uint64_t>(std::numeric_limits<int>::max());

// Reports whether any element byte addressed by one Mat is also addressed by
// the other. Unlike equalize_hist_views_overlap this compares raw byte
// intervals row by row, so it is exact even for views of one buffer that
// were reinterpreted with different element types or row steps.
bool mat_storage_overlaps(const cv::Mat &first, const cv::Mat &second) noexcept
{
    if (first.empty() || second.empty() || first.data == nullptr
        || second.data == nullptr) {
        return false;
    }

    if (first.dims != 2 || second.dims != 2) {
        // Conservative for N-dimensional views: compare the addressed spans.
        return first.data < second.dataend && second.data < first.dataend;
    }

    const std::uintptr_t a_start = reinterpret_cast<std::uintptr_t>(first.data);
    const std::uintptr_t b_start = reinterpret_cast<std::uintptr_t>(second.data);
    const std::uint64_t a_length =
        static_cast<std::uint64_t>(first.cols) * first.elemSize();
    const std::uint64_t b_length =
        static_cast<std::uint64_t>(second.cols) * second.elemSize();
    const std::uint64_t a_step = first.rows > 1 ? first.step[0] : a_length;
    const std::uint64_t b_step = second.rows > 1 ? second.step[0] : b_length;
    const std::uint64_t b_rows = static_cast<std::uint64_t>(second.rows);
    const std::uintptr_t b_end = b_start + (b_rows - 1) * b_step + b_length;

    for (int row = 0; row < first.rows; ++row) {
        const std::uintptr_t start =
            a_start + static_cast<std::uint64_t>(row) * a_step;
        const std::uintptr_t end = start + a_length;
        if (start >= b_end) {
            break;
        }
        if (end <= b_start) {
            continue;
        }
        // First row k of second whose byte interval ends after start.
        std::uint64_t k = 0;
        if (start >= b_start + b_length) {
            k = (start - b_start - b_length) / b_step + 1;
        }
        if (k < b_rows && b_start + k * b_step < end) {
            return true;
        }
    }
    return false;
}

// ABI safety: scalarToRawData converts integer morphology border components
// through saturate_cast<uchar/ushort/short>(double), whose reviewed
// implementations call cvRound before narrow-type saturation. Keep the
// double inside signed-int range before native conversion.
bool morphology_integer_border_component_safe(double value) noexcept
{
    return value >= static_cast<double>(std::numeric_limits<int>::min()) &&
           value <= static_cast<double>(std::numeric_limits<int>::max());
}

// Shared raw preflight for generated and borrowed custom masks.
opencv_imgproc_status morphology_request_impl(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t operation, int32_t kernel_source,
    const opencv_core_mat_handle *kernel_handle, int32_t kernel_width,
    int32_t kernel_height, int32_t shape, int32_t explicit_anchor,
    int32_t anchor_x, int32_t anchor_y, int32_t iterations, int32_t border,
    int32_t explicit_border, const double *border_components)
{
    clear_error();
    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK || !src ||
            opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK || !dst)
            return invalid_argument("invalid morphology Mat handle");
        // ABI safety: morphOp and MorphRowFilter access image rows and require
        // supported scalar dispatch types.
        if (src->empty() || src->dims != 2 ||
            (src->depth() != CV_8U && src->depth() != CV_16U &&
             src->depth() != CV_16S && src->depth() != CV_32F &&
             src->depth() != CV_64F))
            return invalid_argument("invalid morphology source");
        if (operation < 0 || operation > 6 || kernel_source < 0 || kernel_source > 1 ||
            explicit_anchor < 0 || explicit_anchor > 1 || iterations <= 0 ||
            explicit_border < 0 || explicit_border > 1)
            return invalid_argument("invalid morphology selector or iterations");
        int cv_border = 0;
        if (!to_opencv_morphology_border(border, cv_border))
            return invalid_argument("invalid morphology border");
        cv::Mat generated;
        const cv::Mat *kernel = nullptr;
        const cv::Mat *custom = nullptr;
        int cv_shape = 0;
        if (kernel_source == 1) {
            if (opencv_core_module_input_mat(kernel_handle, &custom) != OPENCV_CORE_OK || !custom)
                return invalid_argument("invalid morphology kernel handle");
            // ABI safety: countNonZero and preprocess2DKernel require a
            // nonempty two-dimensional byte mask; malformed types/rows can
            // make sparse coordinate indexing access outside allocated data.
            if (custom->empty() || custom->dims != 2 || custom->type() != CV_8UC1 ||
                custom->rows <= 0 || custom->cols <= 0)
                return invalid_argument("invalid custom morphology kernel");
            kernel = custom;
        } else {
            if (kernel_width <= 0 || kernel_height <= 0 ||
                !to_opencv_morphology_shape(shape, cv_shape))
                return invalid_argument("invalid generated morphology kernel");
        }
        const int64_t width = kernel_source ? custom->cols : kernel_width;
        const int64_t height = kernel_source ? custom->rows : kernel_height;
        const int64_t channels = src->channels();
        const int64_t limit = std::numeric_limits<int>::max();
        // ABI safety: native morphOp/IPP compute kernel.rows*kernel.cols in
        // signed int; MorphRowVec/MorphRowFilter/MorphFilter compute width*cn,
        // ksize*cn and sparse pt[k].x*cn in signed int.
        if (width * height > limit ||
            int64_t(src->cols) * channels > limit || width * channels > limit)
            return invalid_argument("morphology dimension arithmetic overflows int");
        const cv::Point anchor = explicit_anchor ? cv::Point(anchor_x, anchor_y) :
            cv::Point(static_cast<int>(width / 2), static_cast<int>(height / 2));
        // ABI safety: getStructuringElement, normalizeAnchor and morphOp use
        // anchor coordinates as kernel indices and pointer offsets.
        if (anchor.x < 0 || anchor.y < 0 || anchor.x >= width || anchor.y >= height)
            return invalid_argument("morphology anchor outside kernel");
        // ABI safety: getStructuringElement's ellipse evaluates r*r and dy*dy
        // in signed int before converting to floating point.
        if (!kernel_source && cv_shape == cv::MORPH_ELLIPSE && height / 2 > 46340)
            return invalid_argument("ellipse radius arithmetic overflows int");
        if (!kernel_source) {
            generated = cv::getStructuringElement(cv_shape,
                cv::Size(kernel_width, kernel_height), anchor);
            kernel = &generated;
        }
        // ABI safety: preprocess2DKernel may leave coords empty for an all-zero
        // mask, while MorphFilter later dereferences &coords[0] and kp[0].
        const int nonzero = cv::countNonZero(*kernel);
        if (!nonzero)
            return invalid_argument("all-zero morphology kernel");
        // ABI safety: morphOp's full-mask rectangular collapse multiplies
        // anchor by iterations and evaluates width+(iterations-1)*(width-1)
        // and its height equivalent in signed int, after the 1x1 early exit.
        if (width * height > 1 && iterations > 1 && nonzero == width * height &&
            (width + (int64_t(iterations) - 1) * (width - 1) > limit ||
             height + (int64_t(iterations) - 1) * (height - 1) > limit ||
             width + (int64_t(iterations) - 1) * (width - 1) > limit / channels ||
             int64_t(anchor.x) * iterations > limit ||
             int64_t(anchor.y) * iterations > limit))
            return invalid_argument("morphology iteration expansion overflows int");
        if (custom && mat_storage_overlaps(*custom, *dst))
            return invalid_argument("morphology kernel overlaps destination");
        cv::Scalar value = cv::morphologyDefaultBorderValue();
        if (explicit_border) {
            if (!border_components)
                return invalid_argument("null morphology border value");
            if (border == OPENCV_IMGPROC_BORDER_CONSTANT) {
                const double max_float = std::numeric_limits<float>::max();
                const bool integer_source = src->depth() == CV_8U ||
                    src->depth() == CV_16U || src->depth() == CV_16S;
                for (int i = 0; i < std::min(src->channels(), 4); ++i)
                    if (!std::isfinite(border_components[i]) ||
                        (src->depth() == CV_32F && std::abs(border_components[i]) > max_float) ||
                        (integer_source &&
                         !morphology_integer_border_component_safe(border_components[i])))
                        return invalid_argument("invalid explicit morphology border component");
                if (src->channels() > 4 &&
                    (border_components[0] != border_components[1] ||
                     border_components[0] != border_components[2] ||
                     border_components[0] != border_components[3]))
                    return invalid_argument("nonuniform morphology border for C5+");
                if (border_components[0] == DBL_MAX && border_components[1] == DBL_MAX &&
                    border_components[2] == DBL_MAX && border_components[3] == DBL_MAX)
                    return invalid_argument("reserved morphology border sentinel");
                value = cv::Scalar(border_components[0], border_components[1],
                                   border_components[2], border_components[3]);
            }
        }
        switch (operation) {
        case 0: cv::erode(*src, *dst, *kernel, anchor, iterations, cv_border, value); break;
        case 1: cv::dilate(*src, *dst, *kernel, anchor, iterations, cv_border, value); break;
        default: {
            int cv_op = 0;
            if (!to_opencv_morphology_operation(operation - 2, cv_op))
                return invalid_argument("invalid morphology operation");
            cv::morphologyEx(*src, *dst, cv_op, *kernel, anchor, iterations, cv_border, value);
        }}
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

bool product_fits_int(std::uint64_t left, std::uint64_t right) noexcept
{
    return left == 0 || right <= native_int_max / left;
}

bool flood_fill_components(
    const cv::Mat &image,
    const opencv_imgproc_scalar4 &new_value,
    const opencv_imgproc_scalar4 &lower,
    const opencv_imgproc_scalar4 &upper,
    const char **message) noexcept
{
    const int channels = std::min(image.channels(), 4);
    const double float_max =
        static_cast<double>(std::numeric_limits<float>::max());

    for (int index = 0; index < channels; ++index) {
        const double value = new_value.values[index];
        const double low = lower.values[index];
        const double high = upper.values[index];
        if (!std::isfinite(value) || !std::isfinite(low)
            || !std::isfinite(high)) {
            // ABI safety: a NaN difference passes OpenCV's "< 0" check and
            // is then narrowed by cvFloor, and scalarToRawData converts
            // nonfinite fill values; both are undefined conversions.
            *message = "flood-fill value and difference components in use "
                       "must be finite";
            return false;
        }
        if (image.depth() == CV_32F
            && (std::fabs(value) > float_max || std::fabs(low) > float_max
                || std::fabs(high) > float_max)) {
            // ABI safety: OpenCV converts these doubles to float with a
            // plain cast; an out-of-range double-to-float cast is undefined.
            *message = "flood-fill components must be representable in "
                       "binary32 for Float32 images";
            return false;
        }
        if (image.depth() != CV_32F
            && (std::fabs(value) > static_cast<double>(native_int_max)
                || std::fabs(low) > static_cast<double>(native_int_max)
                || std::fabs(high) > static_cast<double>(native_int_max))) {
            // ABI safety: for integer images OpenCV rounds the fill value
            // (cvRound) and floors the differences (cvFloor) to int before
            // saturating; larger magnitudes overflow those conversions.
            *message = "flood-fill components exceed the native int range";
            return false;
        }
    }
    return true;
}

bool grabcut_mode(int32_t mode, int &opencv_mode) noexcept
{
    switch (mode) {
    case OPENCV_IMGPROC_GRABCUT_INIT_WITH_RECT:
        opencv_mode = cv::GC_INIT_WITH_RECT;
        return true;
    case OPENCV_IMGPROC_GRABCUT_INIT_WITH_MASK:
        opencv_mode = cv::GC_INIT_WITH_MASK;
        return true;
    case OPENCV_IMGPROC_GRABCUT_EVAL:
        opencv_mode = cv::GC_EVAL;
        return true;
    case OPENCV_IMGPROC_GRABCUT_EVAL_FREEZE_MODEL:
        opencv_mode = cv::GC_EVAL_FREEZE_MODEL;
        return true;
    default:
        return false;
    }
}

// Counts background (GC_BGD/GC_PR_BGD) and foreground (GC_FGD/GC_PR_FGD)
// mask pixels exactly as OpenCV's initGMMs partitions them. Returns false
// when any label is outside 0..3.
bool grabcut_mask_counts(
    const cv::Mat &mask,
    std::int64_t &background,
    std::int64_t &foreground) noexcept
{
    background = 0;
    foreground = 0;
    for (int row = 0; row < mask.rows; ++row) {
        const std::uint8_t *labels = mask.ptr<std::uint8_t>(row);
        for (int col = 0; col < mask.cols; ++col) {
            switch (labels[col]) {
            case cv::GC_BGD:
            case cv::GC_PR_BGD:
                ++background;
                break;
            case cv::GC_FGD:
            case cv::GC_PR_FGD:
                ++foreground;
                break;
            default:
                return false;
            }
        }
    }
    return true;
}

bool grabcut_model_valid(const cv::Mat &model) noexcept
{
    return model.dims == 2 && model.type() == CV_64FC1 && model.rows == 1
        && model.cols == 65;
}

// Validates flood-fill selectors and geometry. Returns nullptr when the
// request is safe to pass to OpenCV, otherwise a diagnostic.
const char *flood_fill_preflight(
    const cv::Mat &img,
    const cv::Mat *msk,
    int32_t connectivity,
    int32_t range_mode,
    int32_t mask_fill_value,
    uint8_t mask_only) noexcept
{
    // ABI safety: the shim itself packs these selectors into OpenCV's
    // flags word (connectivity | value << 8 | mode bits); any other value
    // would set unrelated flag bits or overflow into the mode bits.
    if (connectivity != 4 && connectivity != 8) {
        return "flood-fill connectivity must be 4 or 8";
    }
    if (range_mode != OPENCV_IMGPROC_FLOOD_FILL_FLOATING_RANGE
        && range_mode != OPENCV_IMGPROC_FLOOD_FILL_FIXED_RANGE) {
        return "invalid flood-fill range mode";
    }
    if (mask_only > 1) {
        return "flood-fill mask-only selector must be 0 or 1";
    }
    if (mask_fill_value < 1 || mask_fill_value > 255) {
        return "flood-fill mask value must be in 1 .. 255";
    }
    if (img.dims > 2) {
        // ABI safety: N-dimensional Mats report rows == cols == -1, which
        // the step and pixel-count arithmetic below cannot represent.
        return "flood-fill image must be two-dimensional";
    }
    const std::uint64_t rows = static_cast<std::uint64_t>(img.rows);
    const std::uint64_t cols = static_cast<std::uint64_t>(img.cols);
    if (rows > 65535 || cols > 65535) {
        // ABI safety: OpenCV 4.1-5.0 FFillSegment stores the queued y, l, r,
        // prevl and prevr coordinates as ushort; larger images truncate them
        // and the fill revisits the wrong rows and columns.
        return "flood-fill image dimensions exceed the native 65535 segment "
               "coordinate limit";
    }
    if (!product_fits_int(rows, cols)) {
        // ABI safety: OpenCV accumulates the filled area in int.
        return "flood-fill pixel count exceeds the native int area";
    }
    if (!product_fits_int(img.step[0], rows + 1)) {
        // ABI safety: OpenCV 4.1 narrows image.step to int and forms
        // step * y row offsets in int.
        return "flood-fill image step arithmetic exceeds native int";
    }
    if (msk == nullptr) {
        if (!product_fits_int(rows + 3, cols + 2)) {
            // ABI safety: the private (rows + 2) x (cols + 2) mask uses the
            // same narrowed int step arithmetic.
            return "flood-fill mask geometry exceeds native int";
        }
        return nullptr;
    }
    if (msk->empty()) {
        // ABI safety: OpenCV 4.1 ignores an empty mask and fills a private
        // one, whereas 4.10/5.0 create() it and rebind the caller's mask
        // header; the observable result would depend on the version.
        return "flood-fill mask must be nonempty";
    }
    if (msk->dims > 2
        || !product_fits_int(
            msk->step[0], static_cast<std::uint64_t>(msk->rows) + 1)) {
        // ABI safety: OpenCV 4.1 narrows mask.step to int and forms
        // maskStep * y row offsets in int.
        return "flood-fill mask step arithmetic exceeds native int";
    }
    if (mat_storage_overlaps(img, *msk)) {
        // ABI safety: the fill compares image pixels while writing the
        // mask; shared storage corrupts unread comparison data.
        return "flood-fill mask must not share storage with image";
    }
    return nullptr;
}

opencv_imgproc_status opencv_imgproc_flood_fill_masked_impl(
    opencv_core_mat_handle *image,
    opencv_core_mat_handle *mask,
    bool masked,
    int32_t seed_x,
    int32_t seed_y,
    const opencv_imgproc_scalar4 *new_value,
    const opencv_imgproc_scalar4 *lower_difference,
    const opencv_imgproc_scalar4 *upper_difference,
    int32_t connectivity,
    int32_t range_mode,
    int32_t mask_fill_value,
    uint8_t mask_only,
    int32_t *pixel_count,
    opencv_imgproc_rect_i32 *bounds) noexcept
{
    clear_error();
    if (pixel_count == nullptr || bounds == nullptr) {
        return invalid_argument("flood-fill result output is null");
    }
    *pixel_count = 0;
    *bounds = opencv_imgproc_rect_i32{0, 0, 0, 0};

    try {
        cv::Mat *img = nullptr;
        if (opencv_core_module_output_mat(image, &img) != OPENCV_CORE_OK
            || img == nullptr) {
            return invalid_argument("invalid flood-fill image");
        }
        cv::Mat *msk = nullptr;
        if (masked
            && (opencv_core_module_output_mat(mask, &msk) != OPENCV_CORE_OK
                || msk == nullptr)) {
            return invalid_argument("invalid flood-fill mask");
        }
        if (new_value == nullptr || lower_difference == nullptr
            || upper_difference == nullptr) {
            return invalid_argument("flood-fill scalar input is null");
        }
        const char *message = flood_fill_preflight(
            *img, msk, connectivity, range_mode, mask_fill_value, mask_only);
        if (message != nullptr) {
            return invalid_argument(message);
        }
        if (!flood_fill_components(
                *img, *new_value, *lower_difference, *upper_difference,
                &message)) {
            return invalid_argument(message);
        }

        int flags = static_cast<int>(connectivity)
            | (static_cast<int>(mask_fill_value) << 8);
        if (range_mode == OPENCV_IMGPROC_FLOOD_FILL_FIXED_RANGE) {
            flags |= cv::FLOODFILL_FIXED_RANGE;
        }
        if (mask_only != 0) {
            flags |= cv::FLOODFILL_MASK_ONLY;
        }

        const double *v = new_value->values;
        const double *lo = lower_difference->values;
        const double *hi = upper_difference->values;
        const cv::Scalar fill(v[0], v[1], v[2], v[3]);
        const cv::Scalar low(lo[0], lo[1], lo[2], lo[3]);
        const cv::Scalar high(hi[0], hi[1], hi[2], hi[3]);
        const cv::Point seed(static_cast<int>(seed_x), static_cast<int>(seed_y));
        cv::Rect rect;
        int area = 0;
        if (masked) {
            area = cv::floodFill(*img, *msk, seed, fill, &rect, low, high, flags);
        } else {
            area = cv::floodFill(*img, seed, fill, &rect, low, high, flags);
        }

        *pixel_count = static_cast<int32_t>(area);
        *bounds = opencv_imgproc_rect_i32{
            static_cast<int32_t>(rect.x), static_cast<int32_t>(rect.y),
            static_cast<int32_t>(rect.width),
            static_cast<int32_t>(rect.height)};
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        *pixel_count = 0;
        *bounds = opencv_imgproc_rect_i32{0, 0, 0, 0};
        return translate_current_exception();
    }
}

// Watershed preflight. OpenCV 4.1, 4.10 and 5.0 segmentation.cpp validate
// only type and size, then compute in int: istep = int(src.step),
// mstep = int(markers.step / 4), queue offsets i * mstep + j and
// i * istep + j * 3, and node-pool growth sz * 3 / 2 where the pool holds at
// most one node per pixel.
const char *watershed_preflight(const cv::Mat &src, const cv::Mat &markers) noexcept
{
    if (src.empty() || markers.empty()) {
        // ABI safety: a zero-row Mat may keep a positive column count, and
        // watershed then writes mask[j + mstep * (rows - 1)] through a null
        // data pointer before discovering there is no pixel to process.
        return "watershed source and markers must be nonempty";
    }
    if (src.dims > 2 || markers.dims > 2) {
        // ABI safety: N-dimensional Mats report rows == cols == -1, so
        // their size() compares equal while the offset arithmetic below is
        // meaningless.
        return "watershed source and markers must be two-dimensional";
    }
    const std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    if (!product_fits_int(src.step[0], rows + 1)) {
        // ABI safety: istep is narrowed to int and i * istep row offsets are
        // stored in int queue nodes.
        return "watershed source step arithmetic exceeds native int";
    }
    if (!product_fits_int(markers.step[0] / sizeof(int), rows + 1)) {
        // ABI safety: mstep is narrowed to int and i * mstep marker offsets
        // are stored in int queue nodes.
        return "watershed marker step arithmetic exceeds native int";
    }
    if (!product_fits_int(rows * cols, 5)) {
        // ABI safety: allocWSNodes grows the node pool with int sz * 3 / 2;
        // the pool reaches about 1.5 nodes per pixel.
        return "watershed pixel count exceeds the native node-pool range";
    }
    if (mat_storage_overlaps(src, markers)) {
        // ABI safety: watershed reads source colors while writing markers;
        // shared storage corrupts unread source pixels.
        return "watershed markers must not share storage with source";
    }
    return nullptr;
}

// GrabCut preflight shared by every mode. OpenCV 4.1, 4.10 and 5.0
// grabcut.cpp compute vtxCount = cols * rows,
// edgeCount = 2 * (4 * cols * rows - 3 * (cols + rows) + 2), calcBeta's
// 4 * cols * rows and vertex index p.y * mask.cols + p.x, all in int.
const char *grabcut_state_preflight(
    const cv::Mat *src,
    const cv::Mat *mask,
    const cv::Mat *background,
    const cv::Mat *foreground) noexcept
{
    if (src->dims > 2) {
        // ABI safety: N-dimensional Mats report rows == cols == -1, which the
        // graph-size arithmetic below cannot represent.
        return "GrabCut source must be two-dimensional";
    }
    const std::uint64_t pixels = static_cast<std::uint64_t>(src->rows)
        * static_cast<std::uint64_t>(src->cols);
    if (!product_fits_int(pixels, 8)) {
        // ABI safety: edgeCount = 2 * (4 * cols * rows ...) overflows int.
        return "GrabCut pixel count exceeds the native graph-size range";
    }
    if (src == mask || src == background || src == foreground
        || mask == background || mask == foreground
        || background == foreground) {
        // ABI safety: GrabCut rebinds mask and empty models via create();
        // one header passed twice would alias state that OpenCV treats as
        // independent.
        return "GrabCut source, mask and models must be distinct Mats";
    }
    const cv::Mat *state[3] = {mask, background, foreground};
    for (int first = 0; first < 3; ++first) {
        if (mat_storage_overlaps(*src, *state[first])) {
            // ABI safety: GrabCut reads source colors while writing state.
            return "GrabCut state must not share storage with source";
        }
        for (int second = first + 1; second < 3; ++second) {
            if (mat_storage_overlaps(*state[first], *state[second])) {
                // ABI safety: mask and model writes would corrupt each other.
                return "GrabCut mask and models must not share storage";
            }
        }
    }
    return nullptr;
}

// Pixels OpenCV's initMaskWithRect (identical in 4.1, 4.10 and 5.0) marks as
// probable foreground: it clamps only the origin to zero and then limits
// width and height to the remaining extent.
std::int64_t grabcut_rect_inside_count(
    const cv::Mat &src,
    int32_t rect_x,
    int32_t rect_y,
    int32_t rect_width,
    int32_t rect_height) noexcept
{
    const std::int64_t x = std::max<std::int64_t>(0, rect_x);
    const std::int64_t y = std::max<std::int64_t>(0, rect_y);
    const std::int64_t width = std::min<std::int64_t>(rect_width, src.cols - x);
    const std::int64_t height =
        std::min<std::int64_t>(rect_height, src.rows - y);
    if (width <= 0 || height <= 0) {
        return 0;
    }
    return width * height;
}

// Mode-specific GrabCut preconditions. The common preflight has already
// accepted the geometry and aliasing.
const char *grabcut_mode_preflight(
    int32_t mode,
    const cv::Mat &src,
    const cv::Mat &labels,
    const cv::Mat &background,
    const cv::Mat &foreground,
    int32_t rect_x,
    int32_t rect_y,
    int32_t rect_width,
    int32_t rect_height) noexcept
{
    const std::int64_t pixels =
        static_cast<std::int64_t>(src.rows) * static_cast<std::int64_t>(src.cols);
    const std::int64_t minimum =
        OPENCV_IMGPROC_GRABCUT_MINIMUM_TRAINING_SAMPLES;

    if (mode == OPENCV_IMGPROC_GRABCUT_INIT_WITH_RECT) {
        const std::int64_t inside = grabcut_rect_inside_count(
            src, rect_x, rect_y, rect_width, rect_height);
        if (inside < minimum || pixels - inside < minimum) {
            // ABI safety: OpenCV 4.1 runs kmeans(K = 5) on each training set
            // and asserts N >= K (for an empty set it first forms a Mat from
            // &samples[0] of an empty vector), whereas 4.10/5.0 shrink K.
            return "GrabCut rectangle must leave at least five pixels inside "
                   "and five outside";
        }
        return nullptr;
    }

    if (mode == OPENCV_IMGPROC_GRABCUT_INIT_WITH_MASK) {
        if (labels.dims != 2 || labels.type() != CV_8UC1
            || labels.rows != src.rows || labels.cols != src.cols) {
            // ABI safety: the shim scans the mask below and must not index
            // outside it.
            return "GrabCut mask must be UInt8 C1 with the source geometry";
        }
        std::int64_t bgd = 0;
        std::int64_t fgd = 0;
        if (!grabcut_mask_counts(labels, bgd, fgd)) {
            // ABI safety: the shim's own training-set count (which guards
            // the OpenCV 4.1 kmeans precondition) is defined only for the
            // four labels; OpenCV would reject others only after that scan.
            return "GrabCut mask labels must be in 0 .. 3";
        }
        if (bgd < minimum || fgd < minimum) {
            // ABI safety: same OpenCV 4.1 kmeans(K = 5) precondition as
            // rectangle initialization.
            return "GrabCut mask needs at least five background and five "
                   "foreground pixels";
        }
        return nullptr;
    }

    if (!grabcut_model_valid(background) || !grabcut_model_valid(foreground)) {
        // ABI safety: in evaluation modes OpenCV silently create()s an empty
        // model with all-zero weights (rebinding the caller's header), and the
        // frozen-model graph then receives -log(0) = infinite capacities.
        return "GrabCut models must be Float64 C1 1 x 65";
    }
    return nullptr;
}

// Histogram helpers. Evidence is from histogram.cpp in OpenCV 4.1, 4.10 and
// 5.0 (histPrepareImages, calcHist_8u / calcHist_<T>,
// calcHistLookupTables_8u, calcBackProj_ and compareHist) and from Mat
// setSize in core/matrix.cpp.

// Native storage for one calcHist / calcBackProject call. Every pointer in
// ranges refers into range_storage and dies with this object.
struct native_histogram_request {
    std::vector<int> channels;
    std::vector<int> sizes;
    std::vector<std::array<float, 2>> range_storage;
    std::vector<const float *> ranges;
};

// Largest magnitude OpenCV may convert to int with cvFloor / cvRound.
constexpr double native_int_limit = 2147483647.0;

// Largest sample of an integer source depth; 0 for Float32.
double histogram_sample_limit(int depth) noexcept
{
    if (depth == CV_8U) {
        return 255.0;
    }
    if (depth == CV_16U) {
        return 65535.0;
    }
    return 0.0;
}

const char *histogram_source_preflight(const cv::Mat &src) noexcept
{
    if (src.depth() != CV_8U && src.depth() != CV_16U
        && src.depth() != CV_32F) {
        // ABI safety: the sample scanner and OpenCV's histogram dispatch
        // interpret source storage using only these three typed paths.
        return "histogram source depth must be UInt8, UInt16, or Float32";
    }
    if (src.dims != 2) {
        // ABI safety: histPrepareImages takes imsize from size(); an N-D
        // source reports -1 x -1 and its row loop then walks memory the Mat
        // does not own.
        return "histogram source must be two-dimensional";
    }
    if (!product_fits_int(
            static_cast<std::uint64_t>(src.rows),
            static_cast<std::uint64_t>(src.cols))) {
        // ABI safety: continuous images are flattened into the int
        // cv::Size width = cols * rows.
        return "histogram source pixel count exceeds native int";
    }
    if (src.step[0] / src.elemSize1() > native_int_max) {
        // ABI safety: histPrepareImages narrows step / elemSize1 into the
        // int row delta used for pointer advances.
        return "histogram source step exceeds native int";
    }
    return nullptr;
}

// Validates the raw dimension records and builds the native call arrays.
const char *histogram_request(
    const cv::Mat &src,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t count,
    native_histogram_request &request)
{
    if (count < 1 || count > OPENCV_IMGPROC_HISTOGRAM_MAX_DIMENSIONS) {
        // ABI safety: OpenCV 5.0 Mat stores at most MatShape::MAX_DIMS (10)
        // extents in a fixed array, and the shim sizes its native arrays
        // from count.
        return "histogram dimension count must be in 1 .. 10";
    }
    if (dimensions == nullptr) {
        return "histogram dimensions must not be null";
    }
    const char *message = histogram_source_preflight(src);
    if (message != nullptr) {
        return message;
    }

    const double sample_limit = histogram_sample_limit(src.depth());
    std::uint64_t total = 1;
    for (int32_t index = 0; index < count; ++index) {
        const opencv_imgproc_histogram_dimension &dimension = dimensions[index];
        if (dimension.channel < 0 || dimension.channel >= src.channels()) {
            // ABI safety: the Float32 preflight indexes this selected channel
            // directly before histPrepareImages can check it.
            return "invalid histogram channel";
        }
        if (dimension.bin_count <= 0) {
            // ABI safety: OpenCV 5.0 setSize accepts negative extents, and a
            // zero-bin axis makes 4.10+ clamp bin indices to -1 before the
            // increment.
            return "histogram bin counts must be positive";
        }
        const double lower = dimension.lower_bound;
        const double upper = dimension.upper_bound;
        if (!std::isfinite(lower) || !std::isfinite(upper) || !(lower < upper)) {
            // ABI safety: an infinite bound makes the bin offset
            // -(bins / (upper - lower)) * lower NaN (0 * inf), which cvFloor
            // converts to int with undefined behavior.
            return "histogram ranges must be finite with lower < upper";
        }
        total *= static_cast<std::uint64_t>(dimension.bin_count);
        if (total > native_int_max) {
            // ABI safety: OpenCV 5.0 setSize multiplies size_t steps without
            // an overflow check, so a wrapping bin product under-allocates
            // the dense histogram; the bound also keeps compareHist's int
            // plane length and native int bin indices exact.
            return "histogram bin product exceeds native int";
        }
        if (sample_limit > 0.0) {
            const double scale = dimension.bin_count / (upper - lower);
            const double offset = -scale * lower;
            const double high = sample_limit * scale + offset;
            if (!(std::fabs(offset) < native_int_limit)
                || !(std::fabs(high) < native_int_limit)) {
                // ABI safety: the UInt8 lookup table evaluates
                // cvFloor(j * scale + offset) for every j in 0 .. 255 and
                // UInt16 code does so for every sample before any range
                // test; values outside int are undefined conversions.
                return "histogram range scaling exceeds the native int range";
            }
        }
        request.channels.push_back(static_cast<int>(dimension.channel));
        request.sizes.push_back(static_cast<int>(dimension.bin_count));
        request.range_storage.push_back(
            {dimension.lower_bound, dimension.upper_bound});
    }
    for (const std::array<float, 2> &range : request.range_storage) {
        request.ranges.push_back(range.data());
    }
    return nullptr;
}

// Inspect only samples that the native histogram will evaluate. Each logical
// dimension has its own transform, even when channels are repeated.
const char *histogram_float_samples_preflight(
    const cv::Mat &src, const cv::Mat *mask,
    const native_histogram_request &request)
{
    std::vector<double> scales;
    std::vector<double> offsets;
    for (std::size_t i = 0; i < request.sizes.size(); ++i) {
        const double lower = request.range_storage[i][0];
        const double upper = request.range_storage[i][1];
        const double scale = request.sizes[i] / (upper - lower);
        scales.push_back(scale);
        offsets.push_back(-scale * lower);
    }
    for (int row = 0; row < src.rows; ++row) {
        const float *pixels = src.ptr<float>(row);
        const uchar *selected = mask == nullptr ? nullptr : mask->ptr<uchar>(row);
        for (int col = 0; col < src.cols; ++col) {
            if (selected != nullptr && selected[col] == 0) {
                continue;
            }
            for (std::size_t i = 0; i < request.sizes.size(); ++i) {
                const float sample = pixels[static_cast<std::size_t>(col)
                    * src.channels() + request.channels[i]];
                if (!std::isfinite(sample)) {
                    return "nonfinite Float32 histogram sample";
                }
                // ABI safety: calcHist_<float> and calcBackProj_<float,float>
                // evaluate cvFloor(sample * uniranges[2*i] +
                // uniranges[2*i+1]) before rejecting some out-of-range
                // samples. cvFloor's float-to-int conversion is undefined
                // outside the native int domain. Keep a one-unit margin at
                // both endpoints for conversion and rounding variants.
                const double coordinate = sample * scales[i] + offsets[i];
                if (!std::isfinite(coordinate)
                    || !(coordinate > -native_int_limit
                         && coordinate < native_int_limit)) {
                    return "Float32 histogram sample/range transform exceeds native cvFloor int range";
                }
            }
        }
    }
    return nullptr;
}

// True when hist has exactly the shape calc_hist_impl publishes for sizes:
// bins x 1 for one dimension, otherwise one extent per dimension.
bool histogram_shape_matches(
    const cv::Mat &hist, const std::vector<int> &sizes) noexcept
{
    const std::size_t count = sizes.size();
    if (count == 1) {
        return hist.dims == 2 && hist.rows == sizes[0] && hist.cols == 1;
    }
    if (hist.dims != static_cast<int>(count)) {
        return false;
    }
    for (std::size_t index = 0; index < count; ++index) {
        if (hist.size[static_cast<int>(index)] != sizes[index]) {
            return false;
        }
    }
    return true;
}

bool to_opencv_histogram_comparison(int32_t method, int &opencv_method) noexcept
{
    switch (method) {
    case OPENCV_IMGPROC_HISTCMP_CORREL:
        opencv_method = cv::HISTCMP_CORREL;
        return true;
    case OPENCV_IMGPROC_HISTCMP_CHISQR:
        opencv_method = cv::HISTCMP_CHISQR;
        return true;
    case OPENCV_IMGPROC_HISTCMP_INTERSECT:
        opencv_method = cv::HISTCMP_INTERSECT;
        return true;
    case OPENCV_IMGPROC_HISTCMP_HELLINGER:
        opencv_method = cv::HISTCMP_BHATTACHARYYA;
        return true;
    case OPENCV_IMGPROC_HISTCMP_CHISQR_ALT:
        opencv_method = cv::HISTCMP_CHISQR_ALT;
        return true;
    case OPENCV_IMGPROC_HISTCMP_KL_DIV:
        opencv_method = cv::HISTCMP_KL_DIV;
        return true;
    default:
        return false;
    }
}

// Borrows the Mats and validates everything shared by calcHist and
// calcBackProject. mask may be null when no mask is used.
const char *histogram_inputs(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *mask,
    bool masked,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    const cv::Mat *&src,
    const cv::Mat *&msk,
    native_histogram_request &request)
{
    if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
        || src == nullptr) {
        return "invalid histogram source";
    }
    if (masked
        && (opencv_core_module_input_mat(mask, &msk) != OPENCV_CORE_OK
            || msk == nullptr)) {
        return "invalid histogram mask";
    }
    if (msk != nullptr && (msk->type() != CV_8UC1 || msk->dims != 2
                           || msk->size != src->size)) {
        // ABI safety: the Float32 scanner reads mask rows as UInt8 C1 at
        // source coordinates; other layouts could be read out of bounds.
        return "histogram mask must be matching 2-D UInt8 C1";
    }
    const char *message =
        histogram_request(*src, dimensions, dimension_count, request);
    if (message == nullptr && msk != nullptr && msk->dims == 2
        && msk->step[0] > native_int_max) {
        // ABI safety: histPrepareImages narrows the UInt8 mask row step into
        // an int pointer delta.
        message = "histogram mask step exceeds native int";
    }
    if (message == nullptr && src->depth() == CV_32F) {
        message = histogram_float_samples_preflight(*src, msk, request);
    }
    return message;
}

opencv_imgproc_status calc_hist_impl(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *mask,
    bool masked,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram)
{
    clear_error();

    try {
        cv::Mat *dst = nullptr;
        if (opencv_core_module_output_mat(histogram, &dst) != OPENCV_CORE_OK
            || dst == nullptr) {
            return invalid_argument("invalid histogram output");
        }
        const cv::Mat *src = nullptr;
        const cv::Mat *msk = nullptr;
        native_histogram_request request;
        const char *message = histogram_inputs(
            source, mask, masked, dimensions, dimension_count, src, msk,
            request);
        if (message != nullptr) {
            return invalid_argument(message);
        }

        // A fresh local result keeps a failed call from rebinding *dst and
        // prevents calcHist from reusing (and accumulating into) its data.
        cv::Mat result;
        if (msk != nullptr) {
            cv::calcHist(
                src, 1, request.channels.data(), *msk, result,
                static_cast<int>(dimension_count), request.sizes.data(),
                request.ranges.data(), true, false);
        } else {
            cv::calcHist(
                src, 1, request.channels.data(), cv::noArray(), result,
                static_cast<int>(dimension_count), request.sizes.data(),
                request.ranges.data(), true, false);
        }
        if (dimension_count == 1 && result.dims != 2) {
            // OpenCV 5.0 creates a genuine 1-D Mat where 4.x creates
            // bins x 1; publish the 4.x shape on every release.
            result = cv::Mat(request.sizes[0], 1, CV_32F, result.data).clone();
        }
        *dst = result;
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

// Clamp for pre-scaled integer back projection. saturate_cast<uchar/ushort>
// (float) first converts with cvRound to int, which is undefined outside the
// int range; every value beyond this bound saturates to the same UInt8 /
// UInt16 result as the unclamped product would.
constexpr float back_project_clamp = 1.0e9f;

// Builds the continuous histogram actually handed to calcBackProject.
// Integer depths receive a copy pre-multiplied (in float, as calcBackProj_
// does) and clamped, so OpenCV is then called with scale 1.
cv::Mat back_project_histogram(
    const cv::Mat &hist, int depth, float scale, float &native_scale)
{
    cv::Mat native = hist.isContinuous() ? hist : hist.clone();
    if (depth == CV_32F) {
        native_scale = scale;
        return native;
    }
    cv::Mat scaled = native.clone();
    float *values = scaled.ptr<float>();
    const std::size_t total = scaled.total();
    for (std::size_t index = 0; index < total; ++index) {
        const float product = values[index] * scale;
        values[index] = std::isnan(product)
            ? 0.0f
            : std::min(std::max(product, -back_project_clamp),
                       back_project_clamp);
    }
    native_scale = 1.0f;
    return scaled;
}

// OpenCV 4.x exposes DistanceTypes from imgproc.hpp, while OpenCV 5
// moved that enum to Geometry. distanceTransform still accepts the
// same integer selectors, so keep Imgproc independent of Geometry.
constexpr int native_distance_l1 = 1;
constexpr int native_distance_l2 = 2;
constexpr int native_distance_c = 3;

// ABI safety: 4.1's approximate passes narrow row strides to int and
// multiply row indices by those strides; the padded temporary uses int
// indices with +/-2 neighbors. The precise path builds rows*3+1,
// columns*2 and i*i lookup entries using signed int.
const char *distance_preflight(const cv::Mat &src, int border, bool precise)
{
    const std::uint64_t rows = static_cast<std::uint64_t>(src.rows);
    const std::uint64_t cols = static_cast<std::uint64_t>(src.cols);
    // ABI safety: all three native implementations reinterpret pixels as
    // uchar and index two-dimensional rows; empty/N-D/wrong-type raw inputs
    // can produce invalid row pointers or incorrectly sized pixel reads.
    if (src.empty() || src.dims != 2 || src.type() != CV_8UC1)
        return "distance source must be nonempty 2-D UInt8 C1";
    if (src.step[0] > native_int_max || cols >= native_int_max / rows
        || rows * cols >= native_int_max)
        // ABI safety: 4.1 IPP takes int pixel counts and CV_32S component
        // labeling and pixel k++ require a representable final index.
        return "distance source step or pixel count exceeds native int";
    if (precise) {
        // ABI safety: OpenCV 4.1 trueDistTrans computes i*i in signed int,
        // with i ranging up to max(rows,cols)-1; it also computes 3*rows+1.
        if (rows > (native_int_max - 1) / 3 || cols > native_int_max / 4
            || rows > 46341 || cols > 46341
            || (rows - 1) > native_int_max / (cols * 4))
            return "precise distance dimensions exceed OpenCV 4.1 int limits";
    } else if (border != 0) {
        const std::uint64_t padded_rows = rows + 2 * border;
        const std::uint64_t padded_cols = cols + 2 * border;
        // ABI safety: the 4.1 passes form (i+border)*step and
        // (i+border+/-2)*step as signed int offsets; label and destination
        // passes similarly form i*cols and i*source_step.
        if (padded_rows > native_int_max || padded_cols > native_int_max
            || padded_cols > native_int_max / 4
            || (padded_rows - 1) > native_int_max / padded_cols
            || cols > native_int_max / 4
            || (rows - 1) > native_int_max / (cols * 4)
            || (rows - 1) > native_int_max / src.step[0])
            return "distance row offsets or padded temporary exceed native int";
    } else if ((rows - 1) > native_int_max / src.step[0]
               || (rows - 1) > native_int_max / cols) {
        // ABI safety: UInt8 L1 narrows source and destination step to int
        // and uses int row offsets.
        return "UInt8 distance row offsets exceed native int";
    }
    // ABI safety: the portable raw contract must not publish an undefined
    // nearest-target result (notably labels) when no target exists.
    // The 4.1/4.10/5.0 paths differ in their sentinel outputs with no
    // target (notably precise vs approximate and labeled propagation).
    // Reject before allocation for a portable raw and public contract.
    for (int y = 0; y < src.rows; ++y) {
        const unsigned char *row = src.ptr<unsigned char>(y);
        for (int x = 0; x < src.cols; ++x)
            if (row[x] == 0) return nullptr;
    }
    return "distance source must contain a zero pixel";
}

} // namespace

extern "C" opencv_imgproc_status opencv_imgproc_integral_sum(
    const opencv_core_mat_handle *source, int32_t sum_depth,
    opencv_core_mat_handle *sum)
{
    return integral_execute(source, sum_depth, 1, sum, nullptr, nullptr);
}

extern "C" opencv_imgproc_status opencv_imgproc_integral_sum_squares(
    const opencv_core_mat_handle *source, int32_t sum_depth, int32_t squared_depth,
    opencv_core_mat_handle *sum, opencv_core_mat_handle *squared)
{
    if (!squared) { clear_error(); return invalid_argument("Null squared output"); }
    return integral_execute(source, sum_depth, squared_depth, sum, squared, nullptr);
}

extern "C" opencv_imgproc_status opencv_imgproc_integral_complete(
    const opencv_core_mat_handle *source, int32_t sum_depth, int32_t squared_depth,
    opencv_core_mat_handle *sum, opencv_core_mat_handle *squared,
    opencv_core_mat_handle *tilted)
{
    if (!squared || !tilted) { clear_error(); return invalid_argument("Null integral output"); }
    return integral_execute(source, sum_depth, squared_depth, sum, squared, tilted);
}

extern "C" {

opencv_imgproc_status opencv_imgproc_distance_transform_f32(
    const opencv_core_mat_handle *source, int32_t method,
    opencv_core_mat_handle *destination)
{
    clear_error();
    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr || opencv_core_module_output_mat(destination, &dst)
                != OPENCV_CORE_OK || dst == nullptr)
            return invalid_argument("invalid distance Mat handle");
        int metric, mask;
        switch (method) {
        case 0: metric = native_distance_l1; mask = cv::DIST_MASK_3; break;
        case 1: metric = native_distance_c; mask = cv::DIST_MASK_3; break;
        case 2: metric = native_distance_l2; mask = cv::DIST_MASK_3; break;
        case 3: metric = native_distance_l2; mask = cv::DIST_MASK_5; break;
        case 4: metric = native_distance_l2; mask = cv::DIST_MASK_PRECISE; break;
        default: return invalid_argument("invalid distance method");
        }
        const char *error = distance_preflight(
            *src, mask == cv::DIST_MASK_PRECISE ? 0 :
                mask == cv::DIST_MASK_3 ? 1 : 2, method == 4);
        if (error) return invalid_argument(error);
        cv::Mat result;
        cv::distanceTransform(*src, result, metric, mask, CV_32F);
        *dst = result;
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status opencv_imgproc_distance_transform_l1_u8(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination)
{
    clear_error();
    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr || opencv_core_module_output_mat(destination, &dst)
                != OPENCV_CORE_OK || dst == nullptr)
            return invalid_argument("invalid distance Mat handle");
        const char *error = distance_preflight(*src, 0, false);
        if (error) return invalid_argument(error);
        cv::Mat result;
        cv::distanceTransform(*src, result, native_distance_l1, cv::DIST_MASK_3, CV_8U);
        *dst = result;
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status opencv_imgproc_distance_transform_labeled(
    const opencv_core_mat_handle *source, int32_t metric, int32_t label_mode,
    opencv_core_mat_handle *distances, opencv_core_mat_handle *labels)
{
    clear_error();
    try {
        if (distances == labels)
            return invalid_argument("distance and label outputs must differ");
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr, *lbl = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr || opencv_core_module_output_mat(distances, &dst)
                != OPENCV_CORE_OK || dst == nullptr
            || opencv_core_module_output_mat(labels, &lbl) != OPENCV_CORE_OK
            || lbl == nullptr || dst == lbl)
            return invalid_argument("invalid labeled distance Mat handle");
        int native_metric;
        switch (metric) {
        case 0: native_metric = native_distance_l1; break;
        case 1: native_metric = native_distance_l2; break;
        case 2: native_metric = native_distance_c; break;
        default: return invalid_argument("invalid labeled distance metric");
        }
        if (label_mode != 0 && label_mode != 1)
            return invalid_argument("invalid distance label mode");
        const char *error = distance_preflight(*src, 2, false);
        if (error) return invalid_argument(error);
        cv::Mat result, label_result;
        cv::distanceTransform(*src, result, label_result, native_metric,
            cv::DIST_MASK_5, label_mode == 0 ? cv::DIST_LABEL_CCOMP
                                            : cv::DIST_LABEL_PIXEL);
        *dst = result;
        *lbl = label_result;
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

const char *opencv_imgproc_last_error_message(void)
{
    return last_error_message;
}

opencv_imgproc_status
opencv_imgproc_cvt_color(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t conversion)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        color_conversion_spec spec{};
        if (!color_spec(conversion, spec)) {
            return invalid_argument(
                "unsupported color conversion");
        }
        // ABI safety: reject malformed raw source metadata before native
        // conversion helpers read rows or compute source channel offsets.
        if (src->empty() || src->dims != 2 ||
            src->channels() != spec.source_channels ||
            (src->depth() != CV_8U && src->depth() != CV_16U && src->depth() != CV_32F) ||
            (spec.nonlinear && src->depth() == CV_16U))
            return invalid_argument("invalid color conversion source shape, channels or depth");
        // ABI safety: reachable CvtColorIPPLoop_Invoker implementations in
        // OpenCV 4.1/4.10/5.0 cast original source and output BYTE steps to
        // int before invoking IPP. Standard HSV/HLS and sRGB Lab/Luv do
        // not reach those loops in the selected native branches.
        if (color_may_use_ipp(conversion, src->depth())) {
            const uint64_t limit = static_cast<uint64_t>(std::numeric_limits<int>::max());
            // ABI safety: src->step[0] includes the real parent row stride
            // for a non-contiguous Region, not just its logical width.
            if (src->step[0] > limit)
                return invalid_argument("color source IPP byte stride overflows int");
            const uint64_t output_scalars =
                static_cast<uint64_t>(src->cols) * spec.destination_channels;
            // ABI safety: the new continuous output's byte stride is passed
            // as int by CvtColorIPPLoop_Invoker.
            if (output_scalars > limit / src->elemSize1())
                return invalid_argument("color output IPP byte stride overflows int");
        }
        cv::Mat result;
        cv::cvtColor(*src, result, spec.code, spec.destination_channels);
        *dst = std::move(result);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_resize(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t width,
    int32_t height,
    int32_t interpolation)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_interpolation = 0;

        if (!to_opencv_interpolation(
                interpolation,
                opencv_interpolation)) {
            return invalid_argument("unsupported interpolation method");
        }

        cv::resize(
            *src,
            *dst,
            cv::Size(static_cast<int>(width), static_cast<int>(height)),
            0,
            0,
            opencv_interpolation);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_gaussian_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    double sigma,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_border = 0;

        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported Gaussian blur border");
        }

        cv::GaussianBlur(
            *src,
            *dst,
            cv::Size(
                static_cast<int>(kernel_width),
                static_cast<int>(kernel_height)),
            sigma,
            sigma,
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_get_gaussian_kernel(
    opencv_core_mat_handle *destination,
    int32_t kernel_size,
    double sigma,
    int32_t kernel_depth)
{
    clear_error();

    try {
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: signed kernel sizes that are non-positive or even
        // are used as coefficient-vector extents before OpenCV constructs
        // the returned Mat.
        if (kernel_size <= 0) {
            return invalid_argument(
                "getGaussianKernel size must be positive");
        }

        if ((kernel_size % 2) == 0) {
            return invalid_argument(
                "getGaussianKernel size must be odd");
        }

        // ABI safety: NaN/Inf sigma values propagate into coefficient
        // exponentiation; negative sigma is not a documented automatic
        // sentinel at this ABI.
        if (!std::isfinite(sigma) || sigma < 0.0) {
            return invalid_argument(
                "getGaussianKernel sigma must be finite and nonnegative");
        }

        int opencv_depth = 0;
        if (!to_opencv_gaussian_kernel_depth(kernel_depth, opencv_depth)) {
            return invalid_argument(
                "unsupported getGaussianKernel depth");
        }

        *dst = cv::getGaussianKernel(
            static_cast<int>(kernel_size),
            sigma,
            opencv_depth);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_get_derivative_kernels(
    opencv_core_mat_handle *kernel_x,
    opencv_core_mat_handle *kernel_y,
    int32_t x_order,
    int32_t y_order,
    int32_t kernel_size,
    int32_t normalize,
    int32_t kernel_depth)
{
    clear_error();

    try {
        cv::Mat *kx = nullptr;
        cv::Mat *ky = nullptr;

        opencv_core_status core_status =
            opencv_core_module_output_mat(kernel_x, &kx);

        if (core_status != OPENCV_CORE_OK || kx == nullptr) {
            return invalid_argument("invalid kernel_x Mat");
        }

        core_status = opencv_core_module_output_mat(kernel_y, &ky);

        if (core_status != OPENCV_CORE_OK || ky == nullptr) {
            return invalid_argument("invalid kernel_y Mat");
        }

        // ABI safety: the same native Mat header cannot receive both
        // independently assigned coefficient vectors.
        if (kx == ky) {
            return invalid_argument(
                "getDerivKernels kernel_x and kernel_y must be distinct");
        }

        if (normalize != OPENCV_IMGPROC_DERIVATIVE_KERNELS_UNNORMALIZED
            && normalize != OPENCV_IMGPROC_DERIVATIVE_KERNELS_NORMALIZED) {
            return invalid_argument(
                "unsupported getDerivKernels normalize selector");
        }

        int opencv_depth = 0;
        if (!to_opencv_kernel_coefficient_depth(kernel_depth, opencv_depth)) {
            return invalid_argument(
                "unsupported getDerivKernels depth");
        }

        // ABI safety: signed orders and kernel sizes reach OpenCV's
        // coefficient-vector construction and signed index arithmetic.
        if (x_order < 0 || y_order < 0) {
            return invalid_argument(
                "getDerivKernels orders must be nonnegative");
        }

        if (x_order == 0 && y_order == 0) {
            return invalid_argument(
                "getDerivKernels requires a nonzero derivative order");
        }

        if (kernel_size == OPENCV_IMGPROC_DERIVATIVE_KERNEL_SCHARR) {
            const bool scharr_x = x_order == 1 && y_order == 0;
            const bool scharr_y = x_order == 0 && y_order == 1;
            if (!scharr_x && !scharr_y) {
                return invalid_argument(
                    "getDerivKernels Scharr requires a first derivative");
            }
        } else if (kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_1
                   || kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_3
                   || kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_5
                   || kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_7) {
            const int32_t effective_x =
                (kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_1 && x_order > 0)
                    ? 3
                    : kernel_size;
            const int32_t effective_y =
                (kernel_size == OPENCV_IMGPROC_SOBEL_KERNEL_1 && y_order > 0)
                    ? 3
                    : kernel_size;

            if (x_order >= effective_x || y_order >= effective_y) {
                return invalid_argument(
                    "getDerivKernels orders exceed the effective kernel");
            }
        } else {
            return invalid_argument(
                "unsupported getDerivKernels kernel size");
        }

        cv::getDerivKernels(
            *kx,
            *ky,
            static_cast<int>(x_order),
            static_cast<int>(y_order),
            static_cast<int>(kernel_size),
            normalize != 0,
            opencv_depth);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_median_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_size)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: reject malformed signed C kernel sizes before they
        // reach OpenCV's median-filter allocation and neighborhood access.
        if (kernel_size <= 1) {
            return invalid_argument(
                "median blur kernel size must be greater than 1");
        }

        if ((kernel_size % 2) == 0) {
            return invalid_argument("median blur kernel size must be odd");
        }

        // ABI safety: OpenCV's medianBlur SIMD path copies a neighborhood
        // from src before fully validating channel/depth combinations, so
        // unsupported layouts must not reach cv::medianBlur.
        if (src->dims != 2) {
            return invalid_argument(
                "median blur source must be two-dimensional");
        }

        const int channels = src->channels();
        if (channels != 1 && channels != 3 && channels != 4) {
            return invalid_argument(
                "median blur source must have 1, 3, or 4 channels");
        }

        const int depth = src->depth();
        if (kernel_size == 3 || kernel_size == 5) {
            if (depth != CV_8U && depth != CV_16U && depth != CV_32F) {
                return invalid_argument(
                    "median blur kernel sizes 3 and 5 require CV_8U, CV_16U, or CV_32F");
            }
        } else if (depth != CV_8U) {
            return invalid_argument(
                "median blur kernel sizes greater than 5 require CV_8U");
        }

        cv::medianBlur(*src, *dst, static_cast<int>(kernel_size));
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_box_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: reject non-positive signed C kernel sizes before they
        // reach OpenCV's box-filter allocation and neighborhood access.
        if (kernel_width <= 0) {
            return invalid_argument(
                "box blur kernel width must be greater than 0");
        }

        if (kernel_height <= 0) {
            return invalid_argument(
                "box blur kernel height must be greater than 0");
        }

        // ABI safety: OpenCV's FilterEngine accesses src as a 2-D image
        // before fully rejecting higher-dimensional Mats.
        if (src->dims != 2) {
            return invalid_argument(
                "box blur source must be two-dimensional");
        }

        // ABI safety: OpenCV's box-filter HAL dispatch uses src depth to
        // select typed pointer access before rejecting unsupported depths.
        const int depth = src->depth();
        if (depth != CV_8U && depth != CV_16U && depth != CV_16S
            && depth != CV_32F && depth != CV_64F) {
            return invalid_argument(
                "box blur requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        int opencv_border = 0;

        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported box blur border");
        }

        cv::blur(
            *src,
            *dst,
            cv::Size(
                static_cast<int>(kernel_width),
                static_cast<int>(kernel_height)),
            cv::Point(-1, -1),
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_bilateral_filter(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t diameter,
    double sigma_color,
    double sigma_space,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status =
            opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: negative diameters are reserved as malformed C input.
        // Zero remains the automatic-diameter sentinel passed to OpenCV.
        if (diameter < 0) {
            return invalid_argument(
                "bilateral filter diameter must be nonnegative");
        }

        // ABI safety: OpenCV's bilateral filter accesses src as a 2-D image
        // before fully rejecting higher-dimensional Mats.
        if (src->dims != 2) {
            return invalid_argument(
                "bilateral filter source must be two-dimensional");
        }

        // ABI safety: OpenCV's bilateral-filter dispatch uses src depth to
        // select typed pointer access before rejecting unsupported depths.
        const int depth = src->depth();
        if (depth != CV_8U && depth != CV_32F) {
            return invalid_argument(
                "bilateral filter requires CV_8U or CV_32F");
        }

        // ABI safety: the SIMD bilateral kernels index 1- or 3-channel
        // neighborhoods; other channel counts can cause out-of-bounds access.
        const int channels = src->channels();
        if (channels != 1 && channels != 3) {
            return invalid_argument(
                "bilateral filter requires 1 or 3 channels");
        }

        // ABI safety: NaN/Inf sigmas produce NaN exponential coefficients
        // and out-of-range LUT indices in OpenCV's bilateral kernels.
        // Non-positive values are reserved as malformed C input; OpenCV
        // would otherwise remap them to 1.0 and silently change the
        // requested operation.
        if (!std::isfinite(sigma_color) || sigma_color <= 0.0) {
            return invalid_argument(
                "bilateral filter sigma_color must be positive and finite");
        }

        if (!std::isfinite(sigma_space) || sigma_space <= 0.0) {
            return invalid_argument(
                "bilateral filter sigma_space must be positive and finite");
        }

        int opencv_border = 0;

        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported bilateral filter border");
        }

        // ABI safety: OpenCV documents that bilateralFilter does not work
        // in-place; writing dst while reading the same buffer is undefined.
        if (src == dst || src->data == dst->data) {
            return invalid_argument(
                "bilateral filter does not support in-place operation");
        }

        cv::bilateralFilter(
            *src,
            *dst,
            static_cast<int>(diameter),
            sigma_color,
            sigma_space,
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_erode(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border)
{
    return apply_morphology(
        source,
        destination,
        kernel_width,
        kernel_height,
        shape,
        iterations,
        border,
        morphology_operation::erosion);
}

opencv_imgproc_status
opencv_imgproc_dilate(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border)
{
    return apply_morphology(
        source,
        destination,
        kernel_width,
        kernel_height,
        shape,
        iterations,
        border,
        morphology_operation::dilation);
}

opencv_imgproc_status
opencv_imgproc_morphology_ex(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t operation,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border)
{
    if (operation < 0 || operation > 4)
        return invalid_argument("unsupported morphology operation");
    return opencv_imgproc_morphology_request(source, destination,
        operation + 2, 0, nullptr, kernel_width, kernel_height, shape,
        0, 0, 0, iterations, border, 0, nullptr);
}

opencv_imgproc_status opencv_imgproc_morphology_request(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t operation, int32_t kernel_source,
    const opencv_core_mat_handle *kernel, int32_t kernel_width,
    int32_t kernel_height, int32_t shape, int32_t explicit_anchor,
    int32_t anchor_x, int32_t anchor_y, int32_t iterations, int32_t border,
    int32_t explicit_border, const double *border_components)
{
    return morphology_request_impl(source, destination, operation, kernel_source,
        kernel, kernel_width, kernel_height, shape, explicit_anchor, anchor_x,
        anchor_y, iterations, border, explicit_border, border_components);
}

opencv_imgproc_status
opencv_imgproc_canny(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double lower_threshold,
    double upper_threshold,
    int32_t aperture_selector,
    int32_t gradient_norm_selector)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int aperture = 0;

        if (!to_opencv_canny_aperture(aperture_selector, aperture)) {
            return invalid_argument("unsupported Canny aperture");
        }

        bool l2_gradient = false;

        if (!to_opencv_canny_gradient_norm(
                gradient_norm_selector,
                l2_gradient)) {
            return invalid_argument("unsupported Canny gradient norm");
        }

        cv::Canny(
            *src,
            *dst,
            lower_threshold,
            upper_threshold,
            aperture,
            l2_gradient);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double threshold_value,
    double maximum_value,
    int32_t mode)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_mode = 0;

        if (!to_opencv_threshold_mode(mode, opencv_mode)) {
            return invalid_argument("unsupported threshold mode");
        }

        cv::threshold(*src, *dst, threshold_value, maximum_value, opencv_mode);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_automatic_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double maximum_value,
    int32_t method,
    int32_t mode,
    double *computed_threshold)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        if (computed_threshold == nullptr) {
            return invalid_argument("null computed threshold output");
        }

        int opencv_method = 0;

        if (!to_opencv_automatic_threshold_method(method, opencv_method)) {
            return invalid_argument("unsupported automatic threshold method");
        }

        int opencv_mode = 0;

        if (!to_opencv_threshold_mode(mode, opencv_mode)) {
            return invalid_argument("unsupported threshold mode");
        }

        const double computed = cv::threshold(
            *src, *dst, 0.0, maximum_value, opencv_mode | opencv_method);
        *computed_threshold = computed;
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_adaptive_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t maximum_value,
    int32_t adaptive_method,
    int32_t threshold_mode,
    int32_t block_size,
    double bias)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_method = 0;
        if (!to_opencv_adaptive_threshold_method(
                adaptive_method, opencv_method)) {
            return invalid_argument("unsupported adaptive threshold method");
        }

        int opencv_mode = 0;
        if (!to_opencv_adaptive_threshold_mode(threshold_mode, opencv_mode)) {
            return invalid_argument("unsupported adaptive threshold mode");
        }

        if (maximum_value < 0 || maximum_value > 255) {
            return invalid_argument("adaptive threshold maximum value must be 0 through 255");
        }

        if (block_size <= 1 || (block_size % 2) == 0) {
            return invalid_argument("adaptive threshold block size must be odd and greater than 1");
        }

        if (!std::isfinite(bias)) {
            return invalid_argument("adaptive threshold bias must be finite");
        }

        cv::adaptiveThreshold(*src, *dst, static_cast<double>(maximum_value),
                              opencv_method, opencv_mode, block_size, bias);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_equalize_histogram(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: OpenCV casts src.total() to int and increments 32-bit
        // histogram bins before building the LUT. A 2-D view whose pixel
        // count exceeds INT_MAX overflows those counters and the LUT scale.
        if (!equalize_hist_pixel_count_fits_int(*src)) {
            return invalid_argument(
                "equalizeHist pixel count exceeds 32-bit histogram range");
        }

        // ABI safety: equalizeHist walks src.rows as a 2-D height, then
        // searches hist[] for a nonzero bin. A higher-dimensional Mat can
        // leave that histogram empty and overflow the 256-bin scan.
        if (src->dims != 2) {
            return invalid_argument(
                "equalizeHist source must be two-dimensional");
        }

        // ABI safety: equalizeHist writes dst from a LUT while still reading
        // src row-wise. Same-object in-place is supported, but a distinct
        // overlapping view can be overwritten before remaining source pixels
        // are read.
        if (src != dst && equalize_hist_views_overlap(*src, *dst)) {
            return invalid_argument(
                "equalizeHist destination must not share storage with source");
        }

        cv::equalizeHist(*src, *dst);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_clahe(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double clip_limit,
    int32_t tile_grid_width,
    int32_t tile_grid_height)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);
        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);
        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: CLAHE computes width % tilesX and height % tilesY before
        // it can reject invalid settings; zero tile counts cause division by
        // zero and negative counts make its tile geometry invalid.
        if (tile_grid_width <= 0 || tile_grid_height <= 0) {
            return invalid_argument("CLAHE tile grid dimensions must be positive");
        }

        // ABI safety: CLAHE converts clip_limit * tileSizeTotal / histSize to
        // int. Converting a non-finite floating value to int is undefined.
        if (!std::isfinite(clip_limit)) {
            return invalid_argument("CLAHE clip limit must be finite");
        }

        // ABI safety: CLAHE forms tilesX * tilesY as int for its LUT rows and
        // parallel range. It also adds padding to source dimensions and takes
        // tileSize.area() as int before allocating or indexing the LUT.
        const std::int64_t max_int = std::numeric_limits<int>::max();
        const std::int64_t tiles_x = tile_grid_width;
        const std::int64_t tiles_y = tile_grid_height;
        if (tiles_x > max_int / tiles_y) {
            return invalid_argument("CLAHE tile count exceeds 32-bit range");
        }

        if (src->dims == 2 && src->rows > 0 && src->cols > 0) {
            const std::int64_t padded_width =
                static_cast<std::int64_t>(src->cols)
                + tiles_x - (static_cast<std::int64_t>(src->cols) % tiles_x);
            const std::int64_t padded_height =
                static_cast<std::int64_t>(src->rows)
                + tiles_y - (static_cast<std::int64_t>(src->rows) % tiles_y);
            if (padded_width > max_int || padded_height > max_int) {
                return invalid_argument("CLAHE padded geometry exceeds 32-bit range");
            }

            const std::int64_t tile_width = padded_width / tiles_x;
            const std::int64_t tile_height = padded_height / tiles_y;
            if (tile_width > max_int / tile_height) {
                return invalid_argument("CLAHE tile area exceeds 32-bit range");
            }

            // ABI safety: CLAHE converts clip_limit * tileSizeTotal / histSize
            // to int. Even a finite positive double is unsafe if that result
            // exceeds INT_MAX before OpenCV can report an argument error.
            const double max_clip_limit =
                static_cast<double>(max_int) * 65536.0
                / static_cast<double>(tile_width * tile_height);
            if (clip_limit > max_clip_limit) {
                return invalid_argument("CLAHE clip limit exceeds 32-bit range");
            }
        }

        cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(
            clip_limit, cv::Size(tile_grid_width, tile_grid_height));

        // ABI safety: when dimensions are not divisible by the tile grid,
        // CLAHE_Impl::apply calls copyMakeBorder with BORDER_REFLECT_101.
        // copyMakeBorder sees src.isSubmatrix() and, unless BORDER_ISOLATED
        // is set, uses locateROI and adjustROI to expand the view into its
        // parent wherever border pixels are available. CLAHE does not request
        // BORDER_ISOLATED, so a non-contiguous ROI can incorporate parent
        // pixels into the padded source and LUT. This is present in OpenCV
        // 4.1.0, 4.10.0, and 5.0.0. The row copy and histogram walk respect
        // row stride; they are not the source of the parent pixels. Cloning
        // first drops the submatrix relationship, so the supplied view is
        // treated as an isolated image. Same-object CLAHE also needs that
        // snapshot because interpolation reads source pixels while destination
        // writes could otherwise modify them. The result is copied back only
        // after native execution succeeds. Distinct overlapping views are
        // still rejected: copying into one of them can overwrite unread
        // pixels of the other.
        if (src != dst && equalize_hist_views_overlap(*src, *dst)) {
            return invalid_argument(
                "CLAHE destination must not share storage with source");
        }

        if (src == dst || !src->isContinuous()) {
            const cv::Mat source_copy = src->clone();
            cv::Mat result;
            clahe->apply(source_copy, result);
            result.copyTo(*dst);
        } else {
            clahe->apply(*src, *dst);
        }
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_connected_components_with_stats(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *labels,
    opencv_core_mat_handle *stats,
    opencv_core_mat_handle *centroids,
    int32_t connectivity,
    int32_t *label_count)
{
    clear_error();

    if (label_count == nullptr) {
        return invalid_argument("label count output is null");
    }
    *label_count = 0;

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *label_image = nullptr;
        cv::Mat *statistics = nullptr;
        cv::Mat *centroid_image = nullptr;

        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }
        if (opencv_core_module_output_mat(labels, &label_image) != OPENCV_CORE_OK
            || label_image == nullptr) {
            return invalid_argument("invalid labels Mat");
        }
        if (opencv_core_module_output_mat(stats, &statistics) != OPENCV_CORE_OK
            || statistics == nullptr) {
            return invalid_argument("invalid statistics Mat");
        }
        if (opencv_core_module_output_mat(centroids, &centroid_image)
                != OPENCV_CORE_OK
            || centroid_image == nullptr) {
            return invalid_argument("invalid centroids Mat");
        }

        if (connectivity != 4 && connectivity != 8) {
            return invalid_argument("connectivity must be 4 or 8");
        }

        // ABI safety: passing one cv::Mat header as multiple OutputArrays lets
        // their create calls rebind a previously published output header.
        if (src == label_image || src == statistics || src == centroid_image
            || label_image == statistics || label_image == centroid_image
            || statistics == centroid_image) {
            return invalid_argument("connected-components outputs must be distinct");
        }

        // ABI safety: connected-components reads Source while it writes Labels;
        // overlapping storage can overwrite unread source pixels.
        if (equalize_hist_views_overlap(*src, *label_image)) {
            return invalid_argument("labels must not share storage with source");
        }

        *label_count = cv::connectedComponentsWithStats(
            *src, *label_image, *statistics, *centroid_image, connectivity,
            CV_32S);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_mats_overlap(
    const opencv_core_mat_handle *first,
    const opencv_core_mat_handle *second,
    uint8_t *overlap)
{
    clear_error();

    if (overlap == nullptr) {
        return invalid_argument("overlap output is null");
    }
    *overlap = 0;

    try {
        const cv::Mat *first_mat = nullptr;
        const cv::Mat *second_mat = nullptr;
        if (opencv_core_module_input_mat(first, &first_mat) != OPENCV_CORE_OK
            || first_mat == nullptr) {
            return invalid_argument("invalid first Mat");
        }
        if (opencv_core_module_input_mat(second, &second_mat) != OPENCV_CORE_OK
            || second_mat == nullptr) {
            return invalid_argument("invalid second Mat");
        }
        *overlap = equalize_hist_views_overlap(*first_mat, *second_mat) ? 1 : 0;
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_find_contours(
    const opencv_core_mat_handle *source,
    int32_t retrieval_mode,
    int32_t approximation_mode,
    int32_t offset_x,
    int32_t offset_y,
    opencv_imgproc_contours_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null contours output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);
        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        int opencv_retrieval = 0;
        if (!to_opencv_contour_retrieval_mode(retrieval_mode, opencv_retrieval)) {
            return invalid_argument("unsupported contour retrieval mode");
        }

        int opencv_approximation = 0;
        if (!to_opencv_contour_approximation_mode(
                approximation_mode, opencv_approximation)) {
            return invalid_argument("unsupported contour approximation mode");
        }

        auto *result = new opencv_imgproc_contours_handle;
        try {
            cv::findContours(*src, result->contours, result->hierarchy,
                             opencv_retrieval, opencv_approximation,
                             cv::Point(offset_x, offset_y));
            if (!fits_int32(result->contours.size())) {
                delete result;
                return invalid_argument("contour count exceeds C ABI range");
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_contours_destroy(opencv_imgproc_contours_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_contour_count(
    const opencv_imgproc_contours_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid contour count arguments");
    }
    if (!fits_int32(result->contours.size())) {
        return invalid_argument("contour count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->contours.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_contour_point_count(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid contour point count arguments");
    }
    if (!valid_contour_index(result, contour_index)) {
        return invalid_argument("contour index is out of range");
    }
    const auto &contour = result->contours[static_cast<std::size_t>(contour_index)];
    if (!fits_int32(contour.size())) {
        return invalid_argument("contour point count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(contour.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_contour_copy_points(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    opencv_imgproc_point_i32 *points,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid contour result");
    }
    if (!valid_contour_index(result, contour_index)) {
        return invalid_argument("contour index is out of range");
    }
    const auto &contour = result->contours[static_cast<std::size_t>(contour_index)];
    if (!fits_int32(contour.size())) {
        return invalid_argument("contour point count exceeds C ABI range");
    }
    const int32_t point_count = static_cast<int32_t>(contour.size());
    if (capacity != point_count || (point_count > 0 && points == nullptr)) {
        return invalid_argument("invalid contour point buffer or capacity");
    }
    for (int32_t index = 0; index < point_count; ++index) {
        const cv::Point &point = contour[static_cast<std::size_t>(index)];
        points[index].x = point.x;
        points[index].y = point.y;
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_contour_hierarchy(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    int32_t *next,
    int32_t *previous,
    int32_t *first_child,
    int32_t *parent)
{
    clear_error();
    if (result == nullptr || next == nullptr || previous == nullptr
        || first_child == nullptr || parent == nullptr) {
        return invalid_argument("invalid contour hierarchy arguments");
    }
    if (!valid_contour_index(result, contour_index)) {
        return invalid_argument("contour index is out of range");
    }
    if (result->hierarchy.size() != result->contours.size()) {
        return invalid_argument("contour hierarchy is unavailable");
    }
    const cv::Vec4i &entry = result->hierarchy[static_cast<std::size_t>(contour_index)];
    *next = entry[0];
    *previous = entry[1];
    *first_child = entry[2];
    *parent = entry[3];
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_sobel(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t x_order,
    int32_t y_order,
    int32_t kernel_size,
    double scale,
    double delta,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_depth = 0;
        if (!to_opencv_derivative_depth(destination_depth, opencv_depth)) {
            return invalid_argument("unsupported derivative destination depth");
        }

        int opencv_kernel = 0;
        if (!to_opencv_sobel_kernel(kernel_size, opencv_kernel)) {
            return invalid_argument("unsupported Sobel kernel size");
        }

        // ABI safety: prevents malformed signed orders from reaching OpenCV's
        // derivative-kernel construction and its signed index arithmetic.
        if (!valid_sobel_orders(x_order, y_order, opencv_kernel)) {
            return invalid_argument("invalid Sobel derivative orders for kernel size");
        }

        if (!std::isfinite(scale) || !std::isfinite(delta)) {
            return invalid_argument("Sobel scale and delta must be finite");
        }

        int opencv_border = 0;
        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported Sobel border");
        }

        cv::Sobel(*src, *dst, opencv_depth, x_order, y_order, opencv_kernel,
                  scale, delta, opencv_border);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_scharr(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t axis,
    double scale,
    double delta,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_depth = 0;
        if (!to_opencv_derivative_depth(destination_depth, opencv_depth)) {
            return invalid_argument("unsupported derivative destination depth");
        }

        int dx = 0;
        int dy = 0;
        if (!to_opencv_derivative_axis(axis, dx, dy)) {
            return invalid_argument("unsupported Scharr derivative axis");
        }

        if (!std::isfinite(scale) || !std::isfinite(delta)) {
            return invalid_argument("Scharr scale and delta must be finite");
        }

        int opencv_border = 0;
        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported Scharr border");
        }

        cv::Scharr(*src, *dst, opencv_depth, dx, dy, scale, delta, opencv_border);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_laplacian(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t kernel_size,
    double scale,
    double offset,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        int opencv_depth = 0;
        if (!to_opencv_derivative_depth(destination_depth, opencv_depth)) {
            return invalid_argument("unsupported derivative destination depth");
        }

        if (kernel_size <= 0 || kernel_size > 31 || (kernel_size % 2) == 0) {
            return invalid_argument(
                "Laplacian kernel size must be odd and between 1 and 31");
        }

        if (!std::isfinite(scale)) {
            return invalid_argument("Laplacian scale must be finite");
        }

        if (!std::isfinite(offset)) {
            return invalid_argument("Laplacian offset must be finite");
        }

        int opencv_border = 0;
        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported Laplacian border");
        }

        cv::Laplacian(*src, *dst, opencv_depth, kernel_size, scale, offset,
                      opencv_border);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_filter_2d(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *kernel,
    int32_t destination_depth,
    int32_t anchor_x,
    int32_t anchor_y,
    double offset,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *krn = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(kernel, &krn);

        if (core_status != OPENCV_CORE_OK || krn == nullptr) {
            return invalid_argument("invalid kernel Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: OpenCV's FilterEngine accesses src as a 2-D image
        // before fully rejecting higher-dimensional Mats.
        if (src->dims != 2) {
            return invalid_argument(
                "filter2D source must be two-dimensional");
        }

        // ABI safety: OpenCV's filter2D dispatch uses src depth to select
        // typed pointer access before rejecting unsupported depths.
        const int src_depth = src->depth();
        if (src_depth != CV_8U && src_depth != CV_16U && src_depth != CV_16S
            && src_depth != CV_32F && src_depth != CV_64F) {
            return invalid_argument(
                "filter2D requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        // ABI safety: FilterEngine indexes kernel coefficients as a 2-D
        // single-channel floating-point neighborhood. Empty, higher-dimensional,
        // multi-channel, or integer kernels can cause out-of-bounds access.
        if (krn->empty()) {
            return invalid_argument("filter2D kernel must be non-empty");
        }

        if (krn->dims != 2) {
            return invalid_argument(
                "filter2D kernel must be two-dimensional");
        }

        if (krn->channels() != 1) {
            return invalid_argument(
                "filter2D kernel must have exactly 1 channel");
        }

        const int kernel_depth = krn->depth();
        if (kernel_depth != CV_32F && kernel_depth != CV_64F) {
            return invalid_argument(
                "filter2D kernel must be CV_32F or CV_64F");
        }

        int opencv_depth = 0;
        if (!to_opencv_derivative_depth(destination_depth, opencv_depth)) {
            return invalid_argument("unsupported filter2D destination depth");
        }

        // ABI safety: unsupported source/destination depth combinations
        // reach typed FilterEngine kernels that assume the documented
        // filter_depths matrix before OpenCV fully rejects them.
        if (!valid_filter_depth_combination(src_depth, destination_depth)) {
            return invalid_argument(
                "unsupported filter2D source/destination depth combination");
        }

        const bool centered_anchor = (anchor_x == -1 && anchor_y == -1);
        const bool real_anchor =
            anchor_x >= 0
            && anchor_y >= 0
            && anchor_x < krn->cols
            && anchor_y < krn->rows;

        // ABI safety: mixed or out-of-range anchors are used as kernel
        // offsets in FilterEngine pointer arithmetic.
        if (!centered_anchor && !real_anchor) {
            return invalid_argument("filter2D anchor lies outside the kernel");
        }

        // ABI safety: NaN/Inf offsets propagate through FilterEngine's
        // typed accumulation before OpenCV stores destination pixels.
        if (!std::isfinite(offset)) {
            return invalid_argument("filter2D offset must be finite");
        }

        int opencv_border = 0;
        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported filter2D border");
        }

        const bool depth_changes =
            opencv_depth != -1 && opencv_depth != src_depth;

        // ABI safety: writing a depth-changing destination into the same
        // buffer as src is undefined; OpenCV documents in-place only when
        // destination depth matches source.
        if (depth_changes && (src == dst || src->data == dst->data)) {
            return invalid_argument(
                "filter2D does not support in-place operation when destination depth changes");
        }

        // ABI safety: writing dst while kernel coefficients occupy the
        // same buffer would mutate coefficients during neighborhood access.
        if (krn->data != nullptr && krn->data == dst->data) {
            return invalid_argument(
                "filter2D kernel and destination must not share storage");
        }

        cv::filter2D(
            *src,
            *dst,
            opencv_depth,
            *krn,
            cv::Point(
                static_cast<int>(anchor_x),
                static_cast<int>(anchor_y)),
            offset,
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_sep_filter_2d(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *kernel_x,
    const opencv_core_mat_handle *kernel_y,
    int32_t destination_depth,
    int32_t anchor_x,
    int32_t anchor_y,
    double offset,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *kx = nullptr;
        const cv::Mat *ky = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(kernel_x, &kx);

        if (core_status != OPENCV_CORE_OK || kx == nullptr) {
            return invalid_argument("invalid kernel_x Mat");
        }

        core_status = opencv_core_module_input_mat(kernel_y, &ky);

        if (core_status != OPENCV_CORE_OK || ky == nullptr) {
            return invalid_argument("invalid kernel_y Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: OpenCV's FilterEngine accesses src as a 2-D image
        // before fully rejecting higher-dimensional Mats.
        if (src->dims != 2) {
            return invalid_argument(
                "sepFilter2D source must be two-dimensional");
        }

        // ABI safety: OpenCV's sepFilter2D dispatch uses src depth to select
        // typed pointer access before rejecting unsupported depths.
        const int src_depth = src->depth();
        if (src_depth != CV_8U && src_depth != CV_16U && src_depth != CV_16S
            && src_depth != CV_32F && src_depth != CV_64F) {
            return invalid_argument(
                "sepFilter2D requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        // ABI safety: FilterEngine indexes 1-D kernel coefficients as a
        // neighborhood. Empty, higher-dimensional, multi-channel, integer,
        // or genuine 2-D kernels can cause out-of-bounds access.
        if (kx->empty()) {
            return invalid_argument("sepFilter2D kernel_x must be non-empty");
        }

        if (kx->dims != 2) {
            return invalid_argument(
                "sepFilter2D kernel_x must be two-dimensional");
        }

        if (kx->channels() != 1) {
            return invalid_argument(
                "sepFilter2D kernel_x must have exactly 1 channel");
        }

        const int kernel_x_depth = kx->depth();
        if (kernel_x_depth != CV_32F && kernel_x_depth != CV_64F) {
            return invalid_argument(
                "sepFilter2D kernel_x must be CV_32F or CV_64F");
        }

        if (kx->rows != 1 && kx->cols != 1) {
            return invalid_argument(
                "sepFilter2D kernel_x must be a one-dimensional vector");
        }

        if (ky->empty()) {
            return invalid_argument("sepFilter2D kernel_y must be non-empty");
        }

        if (ky->dims != 2) {
            return invalid_argument(
                "sepFilter2D kernel_y must be two-dimensional");
        }

        if (ky->channels() != 1) {
            return invalid_argument(
                "sepFilter2D kernel_y must have exactly 1 channel");
        }

        const int kernel_y_depth = ky->depth();
        if (kernel_y_depth != CV_32F && kernel_y_depth != CV_64F) {
            return invalid_argument(
                "sepFilter2D kernel_y must be CV_32F or CV_64F");
        }

        if (ky->rows != 1 && ky->cols != 1) {
            return invalid_argument(
                "sepFilter2D kernel_y must be a one-dimensional vector");
        }

        // ABI safety: OpenCV's sepFilter2D HAL path uses one ktype for both
        // kernels and indexes coefficients with that width. Mixed Float32 and
        // Float64 kernels would mis-size coefficient access.
        if (kx->type() != ky->type()) {
            return invalid_argument(
                "sepFilter2D kernel_x and kernel_y must share one type");
        }

        const int x_length = std::max(kx->rows, kx->cols);
        const int y_length = std::max(ky->rows, ky->cols);
        if (x_length <= 0 || y_length <= 0) {
            return invalid_argument(
                "sepFilter2D kernels must have positive length");
        }

        int opencv_depth = 0;
        if (!to_opencv_derivative_depth(destination_depth, opencv_depth)) {
            return invalid_argument(
                "unsupported sepFilter2D destination depth");
        }

        // ABI safety: unsupported source/destination depth combinations
        // reach typed FilterEngine kernels that assume the documented
        // filter_depths matrix before OpenCV fully rejects them.
        if (!valid_filter_depth_combination(src_depth, destination_depth)) {
            return invalid_argument(
                "unsupported sepFilter2D source/destination depth combination");
        }

        const bool centered_anchor = (anchor_x == -1 && anchor_y == -1);
        const bool real_anchor =
            anchor_x >= 0
            && anchor_y >= 0
            && anchor_x < x_length
            && anchor_y < y_length;

        // ABI safety: mixed or out-of-range anchors are used as kernel
        // offsets in FilterEngine pointer arithmetic.
        if (!centered_anchor && !real_anchor) {
            return invalid_argument(
                "sepFilter2D anchor lies outside the kernels");
        }

        // ABI safety: NaN/Inf offsets propagate through FilterEngine's
        // typed accumulation before OpenCV stores destination pixels.
        if (!std::isfinite(offset)) {
            return invalid_argument("sepFilter2D offset must be finite");
        }

        int opencv_border = 0;
        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported sepFilter2D border");
        }

        const bool depth_changes =
            opencv_depth != -1 && opencv_depth != src_depth;

        // ABI safety: writing a depth-changing destination into the same
        // buffer as src is undefined; OpenCV documents in-place only when
        // destination depth matches source.
        if (depth_changes && (src == dst || src->data == dst->data)) {
            return invalid_argument(
                "sepFilter2D does not support in-place operation when destination depth changes");
        }

        // ABI safety: writing dst while kernel coefficients occupy the
        // same buffer would mutate coefficients during neighborhood access.
        if (kx->data != nullptr && kx->data == dst->data) {
            return invalid_argument(
                "sepFilter2D kernel_x and destination must not share storage");
        }

        if (ky->data != nullptr && ky->data == dst->data) {
            return invalid_argument(
                "sepFilter2D kernel_y and destination must not share storage");
        }

        cv::sepFilter2D(
            *src,
            *dst,
            opencv_depth,
            *kx,
            *ky,
            cv::Point(
                static_cast<int>(anchor_x),
                static_cast<int>(anchor_y)),
            offset,
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_pyr_down(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t border)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        const opencv_imgproc_status resolved =
            resolve_pyramid_source_and_destination(
                source,
                destination,
                &src,
                &dst,
                "pyrDown");

        if (resolved != OPENCV_IMGPROC_OK) {
            return resolved;
        }

        if (border == OPENCV_IMGPROC_BORDER_CONSTANT) {
            // ABI safety: OpenCV pyrDown documents BORDER_CONSTANT as
            // unsupported and constructs neighborhood tables before the
            // exception path; reject it as a malformed selector rather than
            // allowing signed index arithmetic on an unsupported mode.
            return invalid_argument("pyrDown does not support Constant_Border");
        }

        int opencv_border = 0;

        if (!to_opencv_pyramid_down_border(border, opencv_border)) {
            return invalid_argument("unsupported pyrDown border");
        }

        const cv::Mat *effective_source = src;
        cv::Mat logical_source;

        // Region semantics: OpenCV 5 may dispatch a submatrix through
        // cv_hal_pyrdown_offset using parent ROI information. Clone only the
        // logical view so all supported versions/backends see the same image.
        if (src->isSubmatrix()) {
            logical_source = src->clone();
            effective_source = &logical_source;
        }

        const opencv_imgproc_status preflight =
            pyramid_down_preflight(*effective_source, *dst, opencv_border);
        if (preflight != OPENCV_IMGPROC_OK)
            return preflight;

        cv::pyrDown(*effective_source, *dst, cv::Size(), opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_pyr_up(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        const opencv_imgproc_status resolved =
            resolve_pyramid_source_and_destination(
                source,
                destination,
                &src,
                &dst,
                "pyrUp");

        if (resolved != OPENCV_IMGPROC_OK) {
            return resolved;
        }

        const opencv_imgproc_status preflight = pyramid_up_preflight(
            *src, *dst,
            static_cast<std::uint64_t>(src->cols) * 2,
            static_cast<std::uint64_t>(src->rows) * 2);
        if (preflight != OPENCV_IMGPROC_OK)
            return preflight;

        cv::pyrUp(*src, *dst, cv::Size(), cv::BORDER_DEFAULT);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_pyr_up_sized(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t width,
    int32_t height)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }
        cv::Mat *dst = nullptr;
        if (opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK
            || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        const opencv_imgproc_status source_status =
            validate_pyramid_source(*src);
        if (source_status != OPENCV_IMGPROC_OK)
            return source_status;

        // ABI safety: pyrUp_ allocates its ring from (width+1)*cn and runs
        // its geometry CV_Assert afterward. Only d == 2s and d == 2s-1 are
        // accepted: native also accepts 2s+1, but 4.1-4.6 leave that extra
        // multichannel column uninitialized and every release skips it for
        // one-column sources, publishing uninitialized pixels.
        const std::int64_t twice_cols =
            static_cast<std::int64_t>(src->cols) * 2;
        const std::int64_t twice_rows =
            static_cast<std::int64_t>(src->rows) * 2;
        if ((width != twice_cols && width != twice_cols - 1) ||
            (height != twice_rows && height != twice_rows - 1)) {
            return invalid_argument(
                "pyrUp explicit size must be 2 * source or 2 * source - 1");
        }

        // Fresh local result: no source/destination alias is possible, and
        // destination is untouched unless native pyrUp succeeds.
        cv::Mat local;
        const opencv_imgproc_status preflight = pyramid_up_preflight(
            *src, local,
            static_cast<std::uint64_t>(width),
            static_cast<std::uint64_t>(height));
        if (preflight != OPENCV_IMGPROC_OK)
            return preflight;

        cv::pyrUp(*src, local, cv::Size(width, height), cv::BORDER_DEFAULT);
        *dst = std::move(local);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_build_pyramid(
    const opencv_core_mat_handle *source,
    int32_t level_count,
    int32_t border,
    opencv_imgproc_pyramid_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null pyramid result output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const opencv_imgproc_status source_status =
            validate_pyramid_source(*src);
        if (source_status != OPENCV_IMGPROC_OK)
            return source_status;

        if (border == OPENCV_IMGPROC_BORDER_CONSTANT) {
            // ABI safety: as for pyrDown, native neighborhood tables are
            // built before BORDER_CONSTANT is rejected.
            return invalid_argument(
                "buildPyramid does not support Constant_Border");
        }
        int opencv_border = 0;
        if (!to_opencv_pyramid_down_border(border, opencv_border)) {
            return invalid_argument("unsupported buildPyramid border");
        }

        // ABI safety: buildPyramid computes maxlevel + 1 and then indexes
        // level 0, so level_count < 1 is an out-of-bounds access. The upper
        // bound keeps the level vector and every geometry small (<= 32)
        // before any native allocation.
        if (level_count < 1 ||
            level_count > pyramid_distinct_level_count(
                static_cast<std::uint64_t>(src->cols),
                static_cast<std::uint64_t>(src->rows))) {
            return invalid_argument(
                "buildPyramid level count exceeds distinct natural levels");
        }

        // Region semantics: level 0 and every pyrDown must see only the
        // logical image; OpenCV 5 pyrDown can route submatrices through
        // cv_hal_pyrdown_offset using parent pixels.
        const cv::Mat logical_source =
            src->isSubmatrix() ? src->clone() : *src;

        const opencv_imgproc_status preflight = build_pyramid_preflight(
            logical_source, level_count, opencv_border);
        if (preflight != OPENCV_IMGPROC_OK)
            return preflight;

        auto *result = new opencv_imgproc_pyramid_handle;
        try {
            // count/copy_level bound every access by levels.size().
            cv::buildPyramid(
                logical_source, result->levels, level_count - 1,
                opencv_border);
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_pyramid_destroy(opencv_imgproc_pyramid_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_pyramid_count(
    const opencv_imgproc_pyramid_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid pyramid count arguments");
    }
    if (!fits_int32(result->levels.size())) {
        return invalid_argument("pyramid level count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->levels.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_pyramid_copy_level(
    const opencv_imgproc_pyramid_handle *result,
    int32_t index,
    opencv_core_mat_handle *destination)
{
    clear_error();

    try {
        if (result == nullptr) {
            return invalid_argument("invalid pyramid result");
        }
        cv::Mat *dst = nullptr;
        if (opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK
            || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }
        // ABI safety: the shim itself indexes the level vector.
        if (index < 0
            || static_cast<std::size_t>(index) >= result->levels.size()) {
            return invalid_argument("pyramid level index is out of range");
        }

        // Native level 0 is a shallow header over the source; publish a deep
        // clone of every level so no returned Mat shares storage with the
        // source or another level. Destination is rebound only on success.
        cv::Mat copy =
            result->levels[static_cast<std::size_t>(index)].clone();
        *dst = std::move(copy);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_match_template(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *templ,
    opencv_core_mat_handle *destination,
    int32_t method)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *tpl = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(templ, &tpl);

        if (core_status != OPENCV_CORE_OK || tpl == nullptr) {
            return invalid_argument("invalid template Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: OpenCV matchTemplate uses image/template type and
        // 2-D extents to size the result and dispatch typed correlation
        // before fully rejecting empty or higher-dimensional Mats.
        if (src->empty()) {
            return invalid_argument("matchTemplate source must be nonempty");
        }

        if (src->dims != 2) {
            return invalid_argument(
                "matchTemplate source must be two-dimensional");
        }

        if (tpl->empty()) {
            return invalid_argument("matchTemplate template must be nonempty");
        }

        if (tpl->dims != 2) {
            return invalid_argument(
                "matchTemplate template must be two-dimensional");
        }

        // ABI safety: OpenCV matchTemplate uses src depth to select typed
        // correlation kernels before rejecting unsupported depths.
        const int depth = src->depth();
        if (depth != CV_8U && depth != CV_32F) {
            return invalid_argument("matchTemplate requires CV_8U or CV_32F");
        }

        const int channels = src->channels();
        if (channels < 1 || channels > 4) {
            return invalid_argument(
                "matchTemplate supports only 1 to 4 channels");
        }

        if (tpl->type() != src->type()) {
            return invalid_argument(
                "matchTemplate source and template types must match");
        }

        // ABI safety: OpenCV may swap image and template when dimensions
        // are reversed. Reject that here so Source remains the search
        // image and Template remains the patch.
        if (tpl->rows > src->rows || tpl->cols > src->cols) {
            return invalid_argument(
                "matchTemplate template must not be larger than source");
        }

        int opencv_method = 0;
        if (!to_opencv_template_matching_method(method, opencv_method)) {
            return invalid_argument("unsupported matchTemplate method");
        }

        // ABI safety: writing dst while reading the same buffer as src
        // or templ is undefined for this size-changing comparison.
        if (src == dst
            || tpl == dst
            || (src->data != nullptr && src->data == dst->data)
            || (tpl->data != nullptr && tpl->data == dst->data)) {
            return invalid_argument(
                "matchTemplate destination must not share storage with source or template");
        }

        cv::matchTemplate(*src, *tpl, *dst, opencv_method);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_warp_affine(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *transform,
    opencv_core_mat_handle *destination,
    int32_t output_width,
    int32_t output_height,
    int32_t interpolation,
    int32_t mapping,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *matrix = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(transform, &matrix);

        if (core_status != OPENCV_CORE_OK || matrix == nullptr) {
            return invalid_argument("invalid transform Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: warpAffine uses src type and dsize to allocate dst
        // and index source pixels. Empty or higher-dimensional src can
        // reach typed remap kernels before OpenCV fully rejects them.
        if (src->empty()) {
            return invalid_argument("warpAffine source must be nonempty");
        }

        if (src->dims != 2) {
            return invalid_argument(
                "warpAffine source must be two-dimensional");
        }

        const int src_depth = src->depth();
        if (src_depth != CV_8U
            && src_depth != CV_16U
            && src_depth != CV_16S
            && src_depth != CV_32F
            && src_depth != CV_64F) {
            return invalid_argument(
                "warpAffine requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        const int src_channels = src->channels();
        if (src_channels < 1 || src_channels > 4) {
            return invalid_argument(
                "warpAffine supports only 1 to 4 channels");
        }

        // ABI safety: warpAffine indexes a 2x3 coefficient matrix as
        // six floating-point values. Empty, higher-dimensional,
        // multi-channel, or integer matrices can cause out-of-bounds
        // or mistyped coefficient access.
        if (matrix->empty()) {
            return invalid_argument("warpAffine transform must be nonempty");
        }

        if (matrix->dims != 2) {
            return invalid_argument(
                "warpAffine transform must be two-dimensional");
        }

        if (matrix->rows != 2 || matrix->cols != 3) {
            return invalid_argument(
                "warpAffine transform must be 2x3");
        }

        if (matrix->channels() != 1) {
            return invalid_argument(
                "warpAffine transform must have exactly 1 channel");
        }

        const int matrix_depth = matrix->depth();
        if (matrix_depth != CV_32F && matrix_depth != CV_64F) {
            return invalid_argument(
                "warpAffine transform must be CV_32F or CV_64F");
        }

        // ABI safety: invertAffineTransform and remap kernels perform
        // arithmetic on the six coefficients. NaN or infinity produce
        // undefined index arithmetic rather than a documented rejection.
        // std::isfinite is required instead of cv::checkRange because
        // checkRange's default upper bound excludes +DBL_MAX.
        if (!floating_transform_is_finite(*matrix)) {
            return invalid_argument(
                "warpAffine transform must contain only finite values");
        }

        if (output_width <= 0 || output_height <= 0) {
            // ABI safety: OpenCV constructs cv::Size from these signed
            // extents and allocates dst before rejecting a zero size.
            return invalid_argument(
                "warpAffine output size must be positive");
        }

        int opencv_interpolation = 0;
        if (!to_opencv_warp_interpolation(
                interpolation, opencv_interpolation)) {
            return invalid_argument("unsupported warpAffine interpolation");
        }

        int opencv_flags = 0;
        if (!to_opencv_warp_mapping_flags(
                mapping, opencv_interpolation, opencv_flags)) {
            return invalid_argument("unsupported warpAffine mapping");
        }

        int opencv_border = 0;
        if (!to_opencv_warp_border(border, opencv_border)) {
            return invalid_argument("unsupported warpAffine border");
        }

        // ABI safety: writing dst while reading the same buffer as src
        // or the transform is undefined for this size-changing warp.
        if (src == dst
            || matrix == dst
            || (src->data != nullptr && src->data == dst->data)
            || (matrix->data != nullptr && matrix->data == dst->data)) {
            return invalid_argument(
                "warpAffine destination must not share storage with source or transform");
        }

        cv::warpAffine(
            *src,
            *dst,
            *matrix,
            cv::Size(output_width, output_height),
            opencv_flags,
            opencv_border,
            cv::Scalar(
                border_value_0,
                border_value_1,
                border_value_2,
                border_value_3));

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_warp_perspective(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *transform,
    opencv_core_mat_handle *destination,
    int32_t output_width,
    int32_t output_height,
    int32_t interpolation,
    int32_t mapping,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *matrix = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(transform, &matrix);

        if (core_status != OPENCV_CORE_OK || matrix == nullptr) {
            return invalid_argument("invalid transform Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: warpPerspective uses src type and dsize to allocate dst
        // and index source pixels. Empty or higher-dimensional src can
        // reach typed remap kernels before OpenCV fully rejects them.
        if (src->empty()) {
            return invalid_argument("warpPerspective source must be nonempty");
        }

        if (src->dims != 2) {
            return invalid_argument(
                "warpPerspective source must be two-dimensional");
        }

        const int src_depth = src->depth();
        if (src_depth != CV_8U
            && src_depth != CV_16U
            && src_depth != CV_16S
            && src_depth != CV_32F
            && src_depth != CV_64F) {
            return invalid_argument(
                "warpPerspective requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        const int src_channels = src->channels();
        if (src_channels < 1 || src_channels > 4) {
            return invalid_argument(
                "warpPerspective supports only 1 to 4 channels");
        }

        // ABI safety: warpPerspective indexes a 3x3 coefficient matrix of
        // floating-point values. Empty, higher-dimensional,
        // multi-channel, or integer matrices can cause out-of-bounds
        // or mistyped coefficient access.
        if (matrix->empty()) {
            return invalid_argument(
                "warpPerspective transform must be nonempty");
        }

        if (matrix->dims != 2) {
            return invalid_argument(
                "warpPerspective transform must be two-dimensional");
        }

        if (matrix->rows != 3 || matrix->cols != 3) {
            return invalid_argument(
                "warpPerspective transform must be 3x3");
        }

        if (matrix->channels() != 1) {
            return invalid_argument(
                "warpPerspective transform must have exactly 1 channel");
        }

        const int matrix_depth = matrix->depth();
        if (matrix_depth != CV_32F && matrix_depth != CV_64F) {
            return invalid_argument(
                "warpPerspective transform must be CV_32F or CV_64F");
        }

        // ABI safety: invert and remap kernels perform arithmetic on the
        // nine coefficients. NaN or infinity produce undefined index
        // arithmetic rather than a documented rejection.
        // std::isfinite is required instead of cv::checkRange because
        // checkRange's default upper bound excludes +DBL_MAX.
        if (!floating_transform_is_finite(*matrix)) {
            return invalid_argument(
                "warpPerspective transform must contain only finite values");
        }

        if (output_width <= 0 || output_height <= 0) {
            // ABI safety: OpenCV constructs cv::Size from these signed
            // extents and allocates dst before rejecting a zero size.
            return invalid_argument(
                "warpPerspective output size must be positive");
        }

        int opencv_interpolation = 0;
        if (!to_opencv_warp_interpolation(
                interpolation, opencv_interpolation)) {
            return invalid_argument(
                "unsupported warpPerspective interpolation");
        }

        int opencv_flags = 0;
        if (!to_opencv_warp_mapping_flags(
                mapping, opencv_interpolation, opencv_flags)) {
            return invalid_argument("unsupported warpPerspective mapping");
        }

        int opencv_border = 0;
        if (!to_opencv_warp_border(border, opencv_border)) {
            return invalid_argument("unsupported warpPerspective border");
        }

        // ABI safety: writing dst while reading the same buffer as src
        // or the transform is undefined for this size-changing warp.
        if (src == dst
            || matrix == dst
            || (src->data != nullptr && src->data == dst->data)
            || (matrix->data != nullptr && matrix->data == dst->data)) {
            return invalid_argument(
                "warpPerspective destination must not share storage with source or transform");
        }

        cv::warpPerspective(
            *src,
            *dst,
            *matrix,
            cv::Size(output_width, output_height),
            opencv_flags,
            opencv_border,
            cv::Scalar(
                border_value_0,
                border_value_1,
                border_value_2,
                border_value_3));

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_warp_polar(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    float center_x, float center_y, double maximum_radius,
    int32_t output_width, int32_t output_height,
    int32_t mapping, int32_t direction, int32_t interpolation)
{
    clear_error();
    try {
        const cv::Mat *src = nullptr;
        cv::Mat *dst = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK || !src ||
            opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK || !dst)
            return invalid_argument("invalid polar Mat handle");
        if ((mapping != 0 && mapping != 1) || (direction != 0 && direction != 1))
            return invalid_argument("invalid polar selector");
        // ABI safety: remap's typed kernels require a supported nonempty 2-D
        // source, and warpPolar's map construction reads its metadata.
        if (src->empty() || src->dims != 2 || src->channels() > 4 ||
            (src->depth() != CV_8U && src->depth() != CV_16U &&
             src->depth() != CV_16S && src->depth() != CV_32F &&
             src->depth() != CV_64F))
            return invalid_argument("unsupported polar source");
        // ABI safety: remap uses signed 16-bit dimensions and warpPolar
        // divides by explicit nonzero geometry.
        if (output_width <= 0 || output_height <= 0 ||
            output_width >= 32767 || output_height >= 32767)
            return invalid_argument("unsafe polar output size");
        if (!std::isfinite(center_x) || !std::isfinite(center_y))
            return invalid_argument("nonfinite polar center");
        // ABI safety: native log and divisions feed map coordinates which
        // remap rounds into signed int; reject degenerate scales first.
        if (!std::isfinite(maximum_radius) ||
            !(maximum_radius > (mapping == 0 ? 0.0 : 1.0)))
            return invalid_argument("unsafe polar radius");
        if (src->cols >= 32767 ||
            (direction == 0 ? src->rows >= 32767 :
             !polar_inverse_rows_safe(src->rows)))
            return invalid_argument("unsafe polar source dimensions");
        int method = 0;
        if (!to_opencv_remap_interpolation(interpolation, method))
            return invalid_argument("unsupported polar interpolation");
        const double scale = (mapping == 0 ? maximum_radius : std::log(maximum_radius)) /
                             (direction == 0 ? output_width : src->cols);
        if (!std::isfinite(scale) || !(scale > 0))
            return invalid_argument("unsafe polar scale");
        const bool nearest = method == cv::INTER_NEAREST;
        if (direction == 0) {
            // ABI safety: both coordinates lie within center +/- radius;
            // Float32 map rounding must stay strictly within int endpoints.
            if (!polar_coordinate_bound_safe(std::abs(static_cast<double>(center_x)) + maximum_radius + 4.0, nearest) ||
                !polar_coordinate_bound_safe(std::abs(static_cast<double>(center_y)) + maximum_radius + 4.0, nearest))
                return invalid_argument("unsafe forward polar map coordinates");
        } else {
            double distance = 0;
            for (int y : {0, output_height - 1})
                for (int x : {0, output_width - 1})
                    distance = std::max(distance, std::hypot(static_cast<double>(x) - center_x,
                                                               static_cast<double>(y) - center_y));
            // ABI safety: warpPolar converts Cartesian offsets to Float32
            // before cartToPolar; an infinite intermediate corrupts the map.
            if (!std::isfinite(distance) ||
                distance >= static_cast<double>(std::numeric_limits<float>::max()) / 2.0)
                return invalid_argument("unsafe inverse polar distance");
            double rho = distance / scale;
            if (mapping != 0) {
                // ABI safety: in 4.1, 4.10 and 5.0 the inverse semilog map
                // uses Float32 Cartesian offsets -> cartToPolar magnitude
                // -> + 1.f -> log -> double rho / Kmag -> Float32 mapx.
                // A mathematical double log1p(distance) misses the upward
                // rounding at 1.f. Bound each Float32 stage upwards; the
                // deliberately broad log envelope also covers the different
                // scalar/SIMD HAL log approximations. Near zero with a tiny
                // scale, reject rather than depend on their last-bit errors.
                if (distance < 1.0e-4 && scale < 1.0e-6)
                    return invalid_argument("unsafe inverse semilog precision");
                const auto up = [](double value) {
                    return std::nextafterf(static_cast<float>(value),
                                           std::numeric_limits<float>::infinity());
                };
                const double x_bound = up(std::max(std::abs(static_cast<double>(center_x)),
                                                   std::abs(static_cast<double>(output_width - 1) - center_x)));
                const double y_bound = up(std::max(std::abs(static_cast<double>(center_y)),
                                                   std::abs(static_cast<double>(output_height - 1) - center_y)));
                // A second upward step encloses Float32 subtraction and
                // cartToPolar's Float32 multiply/add/sqrt rounding.
                const float magnitude = up(std::hypot(up(x_bound), up(y_bound)));
                const float plus_one = up(1.0 + static_cast<double>(magnitude));
                const double log_bound = 2.0 * std::log(static_cast<double>(plus_one)) + 1.0e-6;
                rho = log_bound / scale;
            }
            // ABI safety: angular map receives a one-row wrap offset; the
            // radial map may otherwise overflow Float32 or remap's cvRound.
            // The bound also covers Float32 mapx storage and remap's x32 operand.
            if (!polar_coordinate_bound_safe(rho + 4.0, nearest) ||
                !polar_coordinate_bound_safe(static_cast<double>(src->rows) + 4.0, nearest))
                return invalid_argument("unsafe inverse polar map coordinates");
        }
        // Forward remap sees the actual Region stride; inverse remap sees the
        // packed copyMakeBorder temporary, not the original source stride.
        const size_t source_step = direction == 0 ? src->step[0] :
            static_cast<size_t>(src->cols) * src->elemSize();
        if (direction == 0) {
            if (!remap_uint8_linear_simd_stride_safe(*src, method))
                return invalid_argument("unsafe polar SIMD source stride");
        } else if (method == cv::INTER_LINEAR &&
                   (src->type() == CV_8UC1 || src->type() == CV_8UC3 || src->type() == CV_8UC4) &&
                   (source_step > static_cast<size_t>(std::numeric_limits<int>::max()) || source_step == 0x8000)) {
            // ABI safety: the inverse packed UInt8 Linear step hits the same
            // OpenCV 4.1 RemapVec_8u signed shift at exactly 0x8000.
            return invalid_argument("unsafe inverse polar SIMD stride");
        }
        if (remap_may_use_ipp(src->type(), method, cv::BORDER_CONSTANT) &&
            (source_step > static_cast<size_t>(std::numeric_limits<int>::max()) ||
             static_cast<uint64_t>(output_width) * src->elemSize() >
                 static_cast<uint64_t>(std::numeric_limits<int>::max()))) {
            // ABI safety: OpenCV 4.1/4.10 IPP narrows source and destination
            // strides to int; generated Float32 maps are packed and <32767.
            return invalid_argument("unsafe polar IPP stride");
        }
        if (src == dst || mat_storage_overlaps(*src, *dst))
            return invalid_argument("polar destination overlaps source");
        cv::Mat result;
        // copyMakeBorder may expand an ROI into its parent when wrapping the
        // inverse polar source; clone the view to keep its logical boundary.
        cv::Mat isolated;
        if (direction != 0 && src->isSubmatrix())
            isolated = src->clone();
        const cv::Mat &input = isolated.empty() ? *src : isolated;
        cv::warpPolar(input, result, cv::Size(output_width, output_height),
                      cv::Point2f(center_x, center_y), maximum_radius,
                      method | cv::WARP_FILL_OUTLIERS |
                      (mapping == 0 ? cv::WARP_POLAR_LINEAR : cv::WARP_POLAR_LOG) |
                      (direction == 0 ? 0 : cv::WARP_INVERSE_MAP));
        *dst = std::move(result);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_remap(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *map_x,
    const opencv_core_mat_handle *map_y,
    opencv_core_mat_handle *destination,
    int32_t interpolation,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        const cv::Mat *mx = nullptr;
        const cv::Mat *my = nullptr;
        cv::Mat *dst = nullptr;

        opencv_core_status core_status =
            opencv_core_module_input_mat(source, &src);

        if (core_status != OPENCV_CORE_OK || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        core_status = opencv_core_module_input_mat(map_x, &mx);

        if (core_status != OPENCV_CORE_OK || mx == nullptr) {
            return invalid_argument("invalid map_x Mat");
        }

        core_status = opencv_core_module_input_mat(map_y, &my);

        if (core_status != OPENCV_CORE_OK || my == nullptr) {
            return invalid_argument("invalid map_y Mat");
        }

        core_status = opencv_core_module_output_mat(destination, &dst);

        if (core_status != OPENCV_CORE_OK || dst == nullptr) {
            return invalid_argument("invalid destination Mat");
        }

        // ABI safety: remap uses src type to allocate dst and indexes
        // source pixels through typed kernels. Empty or higher-dimensional
        // src can reach those kernels before OpenCV fully rejects them.
        if (src->empty()) {
            return invalid_argument("remap source must be nonempty");
        }

        if (src->dims != 2) {
            return invalid_argument("remap source must be two-dimensional");
        }

        const int src_depth = src->depth();
        if (src_depth != CV_8U
            && src_depth != CV_16U
            && src_depth != CV_16S
            && src_depth != CV_32F
            && src_depth != CV_64F) {
            return invalid_argument(
                "remap requires CV_8U, CV_16U, CV_16S, CV_32F, or CV_64F");
        }

        const int src_channels = src->channels();
        if (src_channels < 1 || src_channels > 4) {
            return invalid_argument("remap supports only 1 to 4 channels");
        }

        if (src->rows >= 32767 || src->cols >= 32767) {
            // ABI safety: OpenCV remap kernels use 16-bit coordinate
            // tables and document a 32767 size limit. Larger extents can
            // overflow those tables before OpenCV rejects the input.
            return invalid_argument(
                "remap source dimensions must be less than 32767");
        }

        // ABI safety: remap walks Float32 C1 map rows with ptr<float>.
        // Empty, higher-dimensional, multi-channel, or non-float maps
        // can cause out-of-bounds or mistyped coordinate access.
        if (mx->empty()) {
            return invalid_argument("remap map_x must be nonempty");
        }

        if (my->empty()) {
            return invalid_argument("remap map_y must be nonempty");
        }

        if (mx->dims != 2) {
            return invalid_argument("remap map_x must be two-dimensional");
        }

        if (my->dims != 2) {
            return invalid_argument("remap map_y must be two-dimensional");
        }

        if (mx->type() != CV_32FC1) {
            return invalid_argument("remap map_x must be CV_32FC1");
        }

        if (my->type() != CV_32FC1) {
            return invalid_argument("remap map_y must be CV_32FC1");
        }

        if (mx->rows != my->rows || mx->cols != my->cols) {
            return invalid_argument(
                "remap map_x and map_y must have identical geometry");
        }

        if (mx->rows >= 32767 || mx->cols >= 32767) {
            // ABI safety: remap output size equals map size and uses
            // 16-bit coordinate tables. Walking a map at or above 32767
            // can overflow those tables before OpenCV rejects it.
            return invalid_argument(
                "remap map dimensions must be less than 32767");
        }

        int opencv_interpolation = 0;
        if (!to_opencv_remap_interpolation(
                interpolation, opencv_interpolation)) {
            return invalid_argument("unsupported remap interpolation");
        }

        if (!remap_uint8_linear_simd_stride_safe(*src, opencv_interpolation)) {
            return invalid_argument("remap UInt8 Linear SIMD source byte stride is unsafe");
        }

        // ABI safety: validate before OpenCV rounds Float32 source coordinates
        // to int (including the Float32 multiplication by INTER_TAB_SIZE).
        if (!float32_map_coordinates_safe(*mx, opencv_interpolation == cv::INTER_NEAREST)) {
            return invalid_argument(
                "remap map_x must contain only finite, safely roundable values");
        }

        if (!float32_map_coordinates_safe(*my, opencv_interpolation == cv::INTER_NEAREST)) {
            return invalid_argument(
                "remap map_y must contain only finite, safely roundable values");
        }

        int opencv_border = 0;
        if (!to_opencv_remap_border(border, opencv_border)) {
            return invalid_argument("unsupported remap border");
        }

        // ABI safety: writing dst while reading the same buffer as src
        // or a map is undefined; OpenCV documents remap as not in-place.
        if (src == dst
            || mx == dst
            || my == dst
            || (src->data != nullptr && src->data == dst->data)
            || (mx->data != nullptr && mx->data == dst->data)
            || (my->data != nullptr && my->data == dst->data)) {
            return invalid_argument(
                "remap destination must not share storage with source or maps");
        }

        if (remap_may_use_ipp(src->type(), opencv_interpolation, opencv_border)) {
            const uint64_t limit = static_cast<uint64_t>(std::numeric_limits<int>::max());
            // ABI safety: IPPRemapInvoker casts src.step directly to int.
            if (src->step[0] > limit)
                return invalid_argument("remap IPP source byte stride overflows int");
            // ABI safety: IPPRemapInvoker casts map1.step directly to int.
            if (mx->step[0] > limit)
                return invalid_argument("remap IPP map_x byte stride overflows int");
            // ABI safety: IPPRemapInvoker casts map2.step directly to int.
            if (my->step[0] > limit)
                return invalid_argument("remap IPP map_y byte stride overflows int");
            // ABI safety: IPPRemapInvoker casts dst.step directly to int.
            // The local result is newly allocated and has a packed row stride.
            const uint64_t output_row_bytes =
                static_cast<uint64_t>(mx->cols) * static_cast<uint64_t>(src->elemSize());
            if (output_row_bytes > limit)
                return invalid_argument("remap IPP destination byte stride overflows int");
        }

        cv::Mat result;
        cv::remap(
            *src,
            result,
            *mx,
            *my,
            opencv_interpolation,
            opencv_border,
            cv::Scalar(
                border_value_0,
                border_value_1,
                border_value_2,
                border_value_3));

        *dst = std::move(result);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

// ABI safety: native convertMaps flattens continuous maps (width *= height)
// and C2 SIMD paths double an element index. 32766^2 = 1073610756 < 2^30,
// so both the flattened width and doubled index fit signed int.
bool encoded_map(const cv::Mat &m, int type) noexcept
{
    return !m.empty() && m.dims == 2 && m.type() == type &&
           m.rows < 32767 && m.cols < 32767;
}

opencv_imgproc_status opencv_imgproc_convert_remap_maps(
    const opencv_core_mat_handle *map1, const opencv_core_mat_handle *map2,
    opencv_core_mat_handle *output1, opencv_core_mat_handle *output2,
    int32_t mode, int32_t nearest_only)
{
    clear_error();
    if (!map1 || !map2 || !output1 || !output2 || output1 == output2)
        return invalid_argument("invalid or duplicate map handles");
    try {
        const cv::Mat *a = nullptr, *b = nullptr;
        cv::Mat *out1 = nullptr, *out2 = nullptr;
        if (opencv_core_module_input_mat(map1, &a) != OPENCV_CORE_OK ||
            opencv_core_module_input_mat(map2, &b) != OPENCV_CORE_OK ||
            opencv_core_module_output_mat(output1, &out1) != OPENCV_CORE_OK ||
            opencv_core_module_output_mat(output2, &out2) != OPENCV_CORE_OK ||
            !a || !b || !out1 || !out2 || out1 == out2)
            return invalid_argument("invalid map handle");
        if (mode < 0 || mode > 5 || (nearest_only != 0 && nearest_only != 1))
            return invalid_argument("invalid map conversion selector");
        const bool separate = mode == 0 || mode == 4;
        const bool fixed = mode == 2 || mode == 3;
        if (!encoded_map(*a, fixed ? CV_16SC2 : separate ? CV_32FC1 : CV_32FC2))
            return invalid_argument("invalid primary map type or size");
        if (separate && (!encoded_map(*b, CV_32FC1) || b->size() != a->size()))
            return invalid_argument("invalid separate map geometry or type");
        if (fixed && !b->empty() &&
            (!encoded_map(*b, CV_16UC1) || b->size() != a->size()))
            return invalid_argument("invalid fixed coefficient map");
        if ((mode == 1 || mode == 5) && !b->empty())
            return invalid_argument("interleaved map requires empty second map");
        if ((mode == 0 || mode == 1) &&
            (!float32_map_coordinates_safe(*a, nearest_only != 0) ||
             (separate && !float32_map_coordinates_safe(*b, nearest_only != 0))))
            return invalid_argument("unsafe Float32 map coordinate");
        if (a == out1 || a == out2 || b == out1 || b == out2 ||
            (out1->data && (out1->data == a->data || out1->data == b->data)) ||
            (out2->data && (out2->data == a->data || out2->data == b->data)) ||
            (out1->data && out1->data == out2->data))
            return invalid_argument("map output aliases input or other output");
        cv::Mat first, second;
        if (mode == 0 || mode == 1)
            cv::convertMaps(*a, *b, first, second, CV_16SC2, nearest_only != 0);
        else if (mode == 2 || mode == 3) {
            const bool nn = b->empty();
            if (mode == 2)
                cv::convertMaps(*a, *b, first, second, CV_32FC2, nn);
            else if (nn) {
                cv::Mat xy, unused;
                cv::convertMaps(*a, *b, xy, unused, CV_32FC2, true);
                cv::extractChannel(xy, first, 0);
                cv::extractChannel(xy, second, 1);
            } else
                cv::convertMaps(*a, *b, first, second, CV_32FC1, false);
        } else if (mode == 4) {
            cv::Mat channels[] = {*a, *b};
            cv::merge(channels, 2, first);
        } else {
            cv::extractChannel(*a, first, 0);
            cv::extractChannel(*a, second, 1);
        }
        *out1 = std::move(first);
        *out2 = std::move(second);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status opencv_imgproc_remap_encoded(
    const opencv_core_mat_handle *source, const opencv_core_mat_handle *map1,
    const opencv_core_mat_handle *map2, opencv_core_mat_handle *destination,
    int32_t mode, int32_t interpolation, int32_t border,
    double border_value_0, double border_value_1,
    double border_value_2, double border_value_3)
{
    clear_error();
    if (!source || !map1 || !map2 || !destination)
        return invalid_argument("null Remap handle");
    try {
        const cv::Mat *src = nullptr, *a = nullptr, *b = nullptr;
        cv::Mat *dst = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK ||
            opencv_core_module_input_mat(map1, &a) != OPENCV_CORE_OK ||
            opencv_core_module_input_mat(map2, &b) != OPENCV_CORE_OK ||
            opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK ||
            !src || !a || !b || !dst)
            return invalid_argument("invalid Remap handle");
        if (mode != 0 && mode != 1)
            return invalid_argument("invalid Remap map selector");
        // ABI safety: RemapInvoker dereferences typed map rows before rejecting
        // malformed geometry or type; the short coordinate tables need <32767.
        if (!encoded_map(*a, mode == 0 ? CV_32FC2 : CV_16SC2))
            return invalid_argument("invalid primary Remap map");
        if (mode == 0 ? !b->empty() :
            (!b->empty() && (!encoded_map(*b, CV_16UC1) || b->size() != a->size())))
            return invalid_argument("invalid secondary Remap map");
        // ABI safety: typed source kernels access only two-dimensional
        // supported-depth/channel pixels; 16-bit coordinate tables bound size.
        if (src->empty() || src->dims != 2 || src->rows >= 32767 ||
            src->cols >= 32767 || src->channels() > 4 ||
            (src->depth() != CV_8U && src->depth() != CV_16U &&
             src->depth() != CV_16S && src->depth() != CV_32F &&
             src->depth() != CV_64F))
            return invalid_argument("invalid Remap source");
        int method = 0, edge = 0;
        if (!to_opencv_remap_interpolation(interpolation, method) ||
            !to_opencv_remap_border(border, edge))
            return invalid_argument("invalid Remap selector");
        // ABI safety: without coefficients non-nearest RemapInvoker reads an
        // empty coefficient row through ptr<ushort>.
        if (mode == 1 && b->empty() && method != cv::INTER_NEAREST)
            return invalid_argument("nearest-only map cannot interpolate");
        if (!remap_uint8_linear_simd_stride_safe(*src, method))
            return invalid_argument("unsafe Remap SIMD source stride");
        if (mode == 0 && !float32_map_coordinates_safe(*a, method == cv::INTER_NEAREST))
            return invalid_argument("unsafe Float32 Remap coordinate");
        if (src == dst || a == dst || b == dst ||
            (dst->data && (dst->data == src->data || dst->data == a->data ||
                           dst->data == b->data)))
            return invalid_argument("Remap destination aliases an input");
        cv::Mat result;
        cv::remap(*src, result, *a, *b, method, edge,
                  cv::Scalar(border_value_0, border_value_1,
                             border_value_2, border_value_3));
        *dst = std::move(result);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_draw_line(
    opencv_core_mat_handle *image,
    int32_t start_x,
    int32_t start_y,
    int32_t finish_x,
    int32_t finish_y,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t thickness,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        int opencv_thickness = 0;
        if (!drawing_thickness(
                OPENCV_IMGPROC_DRAW_OUTLINE,
                thickness,
                opencv_thickness,
                &message)) {
            return invalid_argument(message);
        }

        cv::line(
            *img,
            cv::Point(static_cast<int>(start_x), static_cast<int>(start_y)),
            cv::Point(static_cast<int>(finish_x), static_cast<int>(finish_y)),
            color,
            opencv_thickness,
            opencv_line,
            0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_draw_arrow(
    opencv_core_mat_handle *image, int32_t start_x, int32_t start_y,
    int32_t finish_x, int32_t finish_y, double color_0, double color_1,
    double color_2, double color_3, double tip_length, int32_t thickness,
    int32_t line_style)
{
    clear_error();
    try {
        cv::Mat *img = nullptr;
        if (opencv_core_module_output_mat(image, &img) != OPENCV_CORE_OK || !img)
            return invalid_argument("invalid drawing image");
        const char *message = nullptr;
        if (!drawing_image(*img, &message)) return invalid_argument(message);
        cv::Scalar color;
        if (!drawing_color(*img, color_0, color_1, color_2, color_3, color, &message))
            return invalid_argument(message);
        int line = 0, thick = 0;
        if (!drawing_line_style(line_style, *img, line, &message) ||
            !drawing_thickness(OPENCV_IMGPROC_DRAW_OUTLINE, thickness, thick, &message))
            return invalid_argument(message);
        const int64_t dx = static_cast<int64_t>(start_x) - finish_x;
        const int64_t dy = static_cast<int64_t>(start_y) - finish_y;
        // ABI safety: native Point subtraction is signed int, and cvRound
        // converts the generated arrowhead coordinates to signed int.
        if (!std::isfinite(tip_length) || tip_length <= 0 || tip_length > 1 ||
            (dx == 0 && dy == 0) ||
            std::abs(dx) > std::numeric_limits<int>::max() ||
            std::abs(dy) > std::numeric_limits<int>::max())
            return invalid_argument("unsafe arrow geometry");
        const double radius = std::hypot(static_cast<double>(dx), static_cast<double>(dy)) * tip_length;
        const double angle = std::atan2(static_cast<double>(dy), static_cast<double>(dx));
        for (int sign : {-1, 1}) {
            const double x = finish_x + radius * std::cos(angle + sign * CV_PI / 4);
            const double y = finish_y + radius * std::sin(angle + sign * CV_PI / 4);
            if (!std::isfinite(x) || !std::isfinite(y) ||
                x < static_cast<double>(std::numeric_limits<int>::min()) + 1 ||
                y < static_cast<double>(std::numeric_limits<int>::min()) + 1 ||
                x > static_cast<double>(std::numeric_limits<int>::max()) - 1 ||
                y > static_cast<double>(std::numeric_limits<int>::max()) - 1)
                return invalid_argument("arrow tip exceeds native coordinate range");
        }
        cv::arrowedLine(*img, cv::Point(start_x, start_y),
                        cv::Point(finish_x, finish_y), color, thick, line, 0, tip_length);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_draw_marker(
    opencv_core_mat_handle *image, int32_t x, int32_t y,
    double color_0, double color_1, double color_2, double color_3,
    int32_t marker, int32_t marker_size, int32_t thickness, int32_t line_style)
{
    clear_error();
    try {
        cv::Mat *img = nullptr;
        if (opencv_core_module_output_mat(image, &img) != OPENCV_CORE_OK || !img)
            return invalid_argument("invalid drawing image");
        const char *message = nullptr;
        if (!drawing_image(*img, &message)) return invalid_argument(message);
        cv::Scalar color;
        if (!drawing_color(*img, color_0, color_1, color_2, color_3, color, &message))
            return invalid_argument(message);
        int line = 0, thick = 0;
        if (!drawing_line_style(line_style, *img, line, &message) ||
            !drawing_thickness(OPENCV_IMGPROC_DRAW_OUTLINE, thickness, thick, &message))
            return invalid_argument(message);
        if (marker < 0 || marker > 6 || marker_size <= 0)
            return invalid_argument("invalid marker selector or size");
        const int64_t half = static_cast<int64_t>(marker_size) / 2;
        // ABI safety: drawMarker constructs endpoints using signed int +/- half.
        for (int32_t coordinate : {x, y})
            if (static_cast<int64_t>(coordinate) - half < std::numeric_limits<int>::min() ||
                static_cast<int64_t>(coordinate) + half > std::numeric_limits<int>::max())
                return invalid_argument("marker endpoint exceeds native coordinate range");
        cv::drawMarker(*img, cv::Point(x, y), color, marker, marker_size, thick, line);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_draw_text(
    opencv_core_mat_handle *image, const char *text, int32_t text_length,
    int32_t x, int32_t y, double color_0, double color_1,
    double color_2, double color_3, int32_t font, double font_scale,
    int32_t thickness,
    uint8_t bottom_left_origin)
{
    clear_error();
    try {
        int64_t excursion = 0;
        if (text_length < 0 || (text_length && !text) ||
            !valid_hershey(font) || bottom_left_origin > 1 ||
            !safe_text_geometry(text_length, font_scale, thickness, &excursion))
            return invalid_argument("invalid text span, selector or geometry");
        cv::Mat *img = nullptr;
        if (opencv_core_module_output_mat(image, &img) != OPENCV_CORE_OK || !img)
            return invalid_argument("invalid drawing image");
        const char *message = nullptr;
        if (!text_image(*img, &message)) return invalid_argument(message);
        cv::Scalar color;
        if (!drawing_color(*img, color_0, color_1, color_2, color_3, color, &message))
            return invalid_argument(message);
        // ABI safety: OpenCV 5 adds advances, linegap and glyph offsets to
        // a 32-bit Point pen. The excursion bounds both axes, including newlines.
        for (int32_t coordinate : {x, y})
            if (static_cast<int64_t>(coordinate) <
                    static_cast<int64_t>(std::numeric_limits<int>::min()) + excursion ||
                static_cast<int64_t>(coordinate) >
                    static_cast<int64_t>(std::numeric_limits<int>::max()) - excursion)
            return invalid_argument("text origin exceeds safe raster range");
        const cv::String bytes(text_length ? text : "", static_cast<size_t>(text_length));
        cv::putText(*img, bytes, cv::Point(x, y), font,
                    font_scale, color, thickness, cv::LINE_8, bottom_left_origin != 0);
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_measure_text(
    const char *text, int32_t text_length, int32_t font, double font_scale,
    int32_t thickness, int32_t *width, int32_t *height,
    int32_t *baseline)
{
    clear_error();
    if (width) *width = 0;
    if (height) *height = 0;
    if (baseline) *baseline = 0;
    try {
        if (!width || !height || !baseline || text_length < 0 ||
            (text_length && !text) || !valid_hershey(font) ||
            !safe_text_geometry(text_length, font_scale, thickness))
            return invalid_argument("invalid text metrics arguments");
        const cv::String bytes(text_length ? text : "", static_cast<size_t>(text_length));
        int base = 0;
        const cv::Size size = cv::getTextSize(bytes, font,
                                              font_scale, thickness, &base);
        *width = size.width; *height = size.height; *baseline = base;
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_font_scale_for_height(
    int32_t pixel_height, int32_t font,
    int32_t thickness, double *scale)
{
    clear_error();
    if (scale) *scale = 0;
    try {
        if (!scale || pixel_height <= 0 || !valid_hershey(font) ||
            thickness <= 0 || thickness > 32767)
            return invalid_argument("invalid font height arguments");
        const double result = cv::getFontScaleFromHeight(
            font, pixel_height, thickness);
        // ABI safety: a nonpositive scale cannot be passed back to putText;
        // reject it at the source instead of publishing an unusable result.
        if (!std::isfinite(result) || result <= 0 ||
            !safe_text_geometry(1, result, thickness))
            return invalid_argument("requested height yields unsafe font scale");
        *scale = result;
        return OPENCV_IMGPROC_OK;
    } catch (...) { return translate_current_exception(); }
}

opencv_imgproc_status
opencv_imgproc_draw_rectangle(
    opencv_core_mat_handle *image,
    int32_t origin_x,
    int32_t origin_y,
    int32_t width,
    int32_t height,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        if (width <= 0 || height <= 0) {
            // ABI safety: saturated_rectangle_far assumes a positive extent.
            // A nonpositive one yields a far corner before the origin, which
            // the two-point rectangle overload normalizes and then paints
            // pixels outside the requested geometry.
            return invalid_argument(
                "drawing rectangle width and height must be positive");
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        int opencv_thickness = 0;
        if (!drawing_thickness(filled, thickness, opencv_thickness, &message)) {
            return invalid_argument(message);
        }

        cv::rectangle(
            *img,
            cv::Point(static_cast<int>(origin_x), static_cast<int>(origin_y)),
            cv::Point(
                saturated_rectangle_far(origin_x, width),
                saturated_rectangle_far(origin_y, height)),
            color,
            opencv_thickness,
            opencv_line,
            0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_draw_circle(
    opencv_core_mat_handle *image,
    int32_t center_x,
    int32_t center_y,
    int32_t radius,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        if (radius <= 0) {
            // ABI safety: circle accepts a zero radius and draws a degenerate
            // point. Reject it before that write.
            return invalid_argument("drawing circle radius must be positive");
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        int opencv_thickness = 0;
        if (!drawing_thickness(filled, thickness, opencv_thickness, &message)) {
            return invalid_argument(message);
        }

        cv::circle(
            *img,
            cv::Point(static_cast<int>(center_x), static_cast<int>(center_y)),
            static_cast<int>(radius),
            color,
            opencv_thickness,
            opencv_line,
            0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_draw_ellipse(
    opencv_core_mat_handle *image,
    int32_t center_x,
    int32_t center_y,
    int32_t axis_width,
    int32_t axis_height,
    double angle,
    double start_angle,
    double end_angle,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        if (axis_width <= 0 || axis_height <= 0) {
            // ABI safety: a nonpositive ellipse axis is shifted into the
            // fixed-point raster and can address pixels outside the image.
            return invalid_argument("drawing ellipse axes must be positive");
        }

        if (!drawing_angles(angle, start_angle, end_angle, &message)) {
            return invalid_argument(message);
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        int opencv_thickness = 0;
        if (!drawing_thickness(filled, thickness, opencv_thickness, &message)) {
            return invalid_argument(message);
        }

        cv::ellipse(
            *img,
            cv::Point(static_cast<int>(center_x), static_cast<int>(center_y)),
            cv::Size(
                static_cast<int>(axis_width),
                static_cast<int>(axis_height)),
            angle,
            start_angle,
            end_angle,
            color,
            opencv_thickness,
            opencv_line,
            0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_draw_polyline(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    uint8_t closed,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t thickness,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        if (point_count < 2) {
            // ABI safety: polylines copies point_count elements. A negative
            // count underflows that copy.
            return invalid_argument(
                "drawing polyline requires at least two points");
        }

        if (points == nullptr) {
            return invalid_argument("drawing polyline points must not be null");
        }

        if (closed > 1) {
            return invalid_argument(
                "drawing polyline closed flag must be 0 or 1");
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        int opencv_thickness = 0;
        if (!drawing_thickness(
                OPENCV_IMGPROC_DRAW_OUTLINE,
                thickness,
                opencv_thickness,
                &message)) {
            return invalid_argument(message);
        }

        const std::vector<cv::Point> native_points =
            native_drawing_points(points, point_count);
        const cv::Point *native_data = native_points.data();
        const int native_count = static_cast<int>(point_count);
        cv::polylines(
            *img,
            &native_data,
            &native_count,
            1,
            closed == 1,
            color,
            opencv_thickness,
            opencv_line,
            0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_fill_polygon(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t line_style)
{
    clear_error();

    try {
        cv::Mat *img = nullptr;
        const opencv_core_status core_status =
            opencv_core_module_output_mat(image, &img);

        if (core_status != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }

        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }

        if (point_count < 3) {
            // ABI safety: fillPoly copies point_count elements. A negative
            // count underflows that copy. Fewer than three points also makes
            // the edge collector read an incomplete polygon.
            return invalid_argument(
                "drawing polygon requires at least three points");
        }

        if (points == nullptr) {
            return invalid_argument("drawing polygon points must not be null");
        }

        cv::Scalar color;
        if (!drawing_color(
                *img, color_0, color_1, color_2, color_3, color, &message)) {
            return invalid_argument(message);
        }

        int opencv_line = 0;
        if (!drawing_line_style(line_style, *img, opencv_line, &message)) {
            return invalid_argument(message);
        }

        const std::vector<cv::Point> native_points =
            native_drawing_points(points, point_count);
        const cv::Point *native_data = native_points.data();
        const int native_count = static_cast<int>(point_count);
        cv::fillPoly(
            *img,
            &native_data,
            &native_count,
            1,
            color,
            opencv_line,
            0,
            cv::Point(0, 0));
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_draw_contours(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    const opencv_imgproc_contour_span *contours,
    int32_t contour_count,
    double color_0, double color_1, double color_2, double color_3,
    uint8_t filled, int32_t thickness, int32_t line_style,
    int32_t offset_x, int32_t offset_y)
{
    clear_error();
    try {
        cv::Mat *img = nullptr;
        if (opencv_core_module_output_mat(image, &img) != OPENCV_CORE_OK || img == nullptr) {
            return invalid_argument("invalid drawing image");
        }
        const char *message = nullptr;
        if (!drawing_image(*img, &message)) {
            return invalid_argument(message);
        }
        if (point_count < 0 || contour_count < 0 ||
            (point_count != 0 && points == nullptr) ||
            (contour_count != 0 && contours == nullptr)) {
            return invalid_argument("invalid contour buffer or count");
        }
        if (filled > 1) {
            return invalid_argument("invalid contour fill selector");
        }
        cv::Scalar color;
        if (!drawing_color(*img, color_0, color_1, color_2, color_3,
                           color, &message)) {
            return invalid_argument(message);
        }
        int native_line = 0;
        if (!drawing_line_style(line_style, *img, native_line, &message)) {
            return invalid_argument(message);
        }
        int native_thickness = 0;
        if (!drawing_thickness(filled, thickness, native_thickness, &message)) {
            return invalid_argument(message);
        }

        // Validate all descriptors before reading any point, allocating native
        // storage or starting rasterization. fillPoly accumulates counts in int.
        int64_t total = 0;
        for (int32_t i = 0; i < contour_count; ++i) {
            const int64_t start = contours[i].first_point;
            const int64_t count = contours[i].point_count;
            if (start < 0 || count <= 0 ||
                start + count > point_count ||
                total + count > std::numeric_limits<int>::max()) {
                return invalid_argument("invalid contour span or total point count");
            }
            total += count;
        }
        if (contour_count == 0) {
            return OPENCV_IMGPROC_OK;
        }
        const int64_t low = std::numeric_limits<int>::min();
        const int64_t high = std::numeric_limits<int>::max();
        for (int32_t i = 0; i < contour_count; ++i) {
            const auto &span = contours[i];
            for (int64_t j = span.first_point;
                 j < static_cast<int64_t>(span.first_point) + span.point_count; ++j) {
                const int64_t x = static_cast<int64_t>(points[j].x) + offset_x;
                const int64_t y = static_cast<int64_t>(points[j].y) + offset_y;
                // ABI safety: drawContours adds the offset in signed Point
                // arithmetic before clipping (including the legacy 4.1 path).
                if (x < low || x > high || y < low || y > high) {
                    return invalid_argument("contour point plus offset exceeds signed int");
                }
            }
        }

        std::vector<std::vector<cv::Point>> native;
        native.reserve(static_cast<std::size_t>(contour_count));
        for (int32_t i = 0; i < contour_count; ++i) {
            const auto &span = contours[i];
            std::vector<cv::Point> shape;
            shape.reserve(static_cast<std::size_t>(span.point_count));
            for (int64_t j = span.first_point;
                 j < static_cast<int64_t>(span.first_point) + span.point_count; ++j) {
                shape.emplace_back(points[j].x, points[j].y);
            }
            native.push_back(std::move(shape));
        }
        // The selected contours are siblings; maxLevel 1 includes every
        // sibling in 4.1's legacy tree iterator. No native hierarchy is used.
        cv::drawContours(*img, native, -1, color, native_thickness,
                         native_line, cv::noArray(), 1,
                         cv::Point(offset_x, offset_y));
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_hough_lines(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    double min_theta,
    double max_theta,
    opencv_imgproc_hough_lines_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough lines output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const char *message = nullptr;
        std::int64_t rows = 0;
        std::int64_t cols = 0;
        if (!hough_source_valid(*src, rows, cols, &message)) {
            return invalid_argument(message);
        }

        // Continuous snapshot: HoughLines documents that it may modify its
        // input, and a view must be processed as its own logical image.
        cv::Mat snapshot = src->clone();
        const std::int64_t nonzero_count = cv::countNonZero(snapshot);
        if (!hough_lines_preflight(
                rows, cols, nonzero_count, rho, theta, threshold, min_theta,
                max_theta, &message)) {
            return invalid_argument(message);
        }

        auto *result = new opencv_imgproc_hough_lines_handle;
        try {
            // Classical call: srn = stn = 0 and no OpenCV 5 use_edgeval.
            // A vector<Vec2f> requests (rho, theta) without votes.
            cv::HoughLines(
                snapshot, result->lines, rho, theta, threshold,
                0.0, 0.0, min_theta, max_theta);
            if (!fits_int32(result->lines.size())) {
                delete result;
                return invalid_argument("Hough line count exceeds C ABI range");
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_hough_lines_destroy(opencv_imgproc_hough_lines_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_hough_lines_count(
    const opencv_imgproc_hough_lines_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid Hough line count arguments");
    }
    if (!fits_int32(result->lines.size())) {
        return invalid_argument("Hough line count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->lines.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_lines_copy(
    const opencv_imgproc_hough_lines_handle *result,
    opencv_imgproc_hough_line *lines,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid Hough line result");
    }
    const std::size_t count = result->lines.size();
    if (!fits_capacity(capacity, count)) {
        return invalid_argument("invalid Hough line buffer capacity");
    }
    if (count > 0 && lines == nullptr) {
        return invalid_argument("null Hough line buffer");
    }
    for (std::size_t index = 0; index < count; ++index) {
        const cv::Vec2f &line = result->lines[index];
        lines[index].rho = line[0];
        lines[index].theta = line[1];
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_segments(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    int32_t min_line_length,
    int32_t max_line_gap,
    opencv_imgproc_hough_segments_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough segments output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const char *message = nullptr;
        std::int64_t rows = 0;
        std::int64_t cols = 0;
        if (!hough_source_valid(*src, rows, cols, &message)
            || !hough_segments_preflight(
                rows, cols, rho, theta, threshold, min_line_length,
                max_line_gap, &message)) {
            return invalid_argument(message);
        }

        cv::Mat snapshot = src->clone();
        auto *result = new opencv_imgproc_hough_segments_handle;
        try {
            // Integer length and gap are exact after OpenCV's cvRound.
            cv::HoughLinesP(
                snapshot, result->segments, rho, theta, threshold,
                static_cast<double>(min_line_length),
                static_cast<double>(max_line_gap));
            if (!fits_int32(result->segments.size())) {
                delete result;
                return invalid_argument(
                    "Hough segment count exceeds C ABI range");
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_hough_segments_destroy(
    opencv_imgproc_hough_segments_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_hough_segments_count(
    const opencv_imgproc_hough_segments_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid Hough segment count arguments");
    }
    if (!fits_int32(result->segments.size())) {
        return invalid_argument("Hough segment count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->segments.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_segments_copy(
    const opencv_imgproc_hough_segments_handle *result,
    opencv_imgproc_hough_segment *segments,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid Hough segment result");
    }
    const std::size_t count = result->segments.size();
    if (!fits_capacity(capacity, count)) {
        return invalid_argument("invalid Hough segment buffer capacity");
    }
    if (count > 0 && segments == nullptr) {
        return invalid_argument("null Hough segment buffer");
    }
    for (std::size_t index = 0; index < count; ++index) {
        const cv::Vec4i &segment = result->segments[index];
        segments[index].x1 = segment[0];
        segments[index].y1 = segment[1];
        segments[index].x2 = segment[2];
        segments[index].y2 = segment[3];
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_circles(
    const opencv_core_mat_handle *source,
    double dp,
    double min_dist,
    int32_t canny_threshold,
    int32_t accumulator_threshold,
    int32_t radius_mode,
    int32_t min_radius,
    int32_t max_radius,
    opencv_imgproc_hough_circles_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough circles output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const char *message = nullptr;
        std::int64_t rows = 0;
        std::int64_t cols = 0;
        if (!hough_source_valid(*src, rows, cols, &message)
            || !hough_circles_preflight(
                rows, cols, dp, min_dist, canny_threshold,
                accumulator_threshold, radius_mode, min_radius, max_radius,
                &message)) {
            return invalid_argument(message);
        }

        // Continuous snapshot so a view is filtered as its own image rather
        // than acquiring parent pixels through Sobel border handling.
        cv::Mat snapshot = src->clone();
        // The centers-only -1 sentinel is produced only here, from the
        // validated private radius mode.
        const int native_max_radius =
            radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC
                ? 0
                : radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_CENTERS_ONLY
                    ? -1
                    : static_cast<int>(max_radius);
        auto *result = new opencv_imgproc_hough_circles_handle;
        try {
            // A vector<Vec3f> requests (x, y, radius) without votes; in
            // centers-only mode GetCircleCenters(Vec3f) writes (x, y, 0).
            cv::HoughCircles(
                snapshot, result->circles, cv::HOUGH_GRADIENT, dp, min_dist,
                static_cast<double>(canny_threshold),
                static_cast<double>(accumulator_threshold),
                static_cast<int>(min_radius), native_max_radius);
            if (!fits_int32(result->circles.size())) {
                delete result;
                return invalid_argument(
                    "Hough circle count exceeds C ABI range");
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_hough_circles_destroy(
    opencv_imgproc_hough_circles_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_hough_circles_count(
    const opencv_imgproc_hough_circles_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid Hough circle count arguments");
    }
    if (!fits_int32(result->circles.size())) {
        return invalid_argument("Hough circle count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->circles.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_circles_copy(
    const opencv_imgproc_hough_circles_handle *result,
    opencv_imgproc_hough_circle *circles,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid Hough circle result");
    }
    const std::size_t count = result->circles.size();
    if (!fits_capacity(capacity, count)) {
        return invalid_argument("invalid Hough circle buffer capacity");
    }
    if (count > 0 && circles == nullptr) {
        return invalid_argument("null Hough circle buffer");
    }
    for (std::size_t index = 0; index < count; ++index) {
        const cv::Vec3f &circle = result->circles[index];
        circles[index].x = circle[0];
        circles[index].y = circle[1];
        circles[index].radius = circle[2];
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_lines_with_votes(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    double min_theta,
    double max_theta,
    opencv_imgproc_hough_line_evidence_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough line evidence output pointer");
    }
    *out_result = nullptr;

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const char *message = nullptr;
        std::int64_t rows = 0;
        std::int64_t cols = 0;
        if (!hough_source_valid(*src, rows, cols, &message)) {
            return invalid_argument(message);
        }

        cv::Mat snapshot = src->clone();
        const std::int64_t nonzero_count = cv::countNonZero(snapshot);
        // The ordinary line preflight is reused unchanged, so both standard
        // detectors accept exactly the same geometry. Its IPP nonzero-product
        // guard is merely conservative here: a Vec3f request never enters
        // the CV_32FC2-only IPP branch.
        if (!hough_lines_preflight(
                rows, cols, nonzero_count, rho, theta, threshold, min_theta,
                max_theta, &message)) {
            return invalid_argument(message);
        }

        auto *result = new opencv_imgproc_hough_line_evidence_handle;
        try {
            // Classical call: srn = stn = 0 and no OpenCV 5 use_edgeval. A
            // vector<Vec3f> is a fixed CV_32FC3 output: (rho, theta, votes).
            std::vector<cv::Vec3f> native;
            cv::HoughLines(
                snapshot, native, rho, theta, threshold,
                0.0, 0.0, min_theta, max_theta);
            if (!fits_int32(native.size())) {
                delete result;
                return invalid_argument(
                    "Hough line evidence count exceeds C ABI range");
            }
            result->lines.reserve(native.size());
            for (const cv::Vec3f &line : native) {
                result->lines.push_back(
                    {static_cast<double>(line[0]),
                     static_cast<double>(line[1]),
                     static_cast<double>(line[2])});
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_hough_line_evidence_destroy(
    opencv_imgproc_hough_line_evidence_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_hough_line_evidence_count(
    const opencv_imgproc_hough_line_evidence_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument("invalid Hough line evidence count arguments");
    }
    if (!fits_int32(result->lines.size())) {
        return invalid_argument("Hough line evidence count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->lines.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_line_evidence_copy(
    const opencv_imgproc_hough_line_evidence_handle *result,
    opencv_imgproc_hough_line_evidence *lines,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid Hough line evidence result");
    }
    const std::size_t count = result->lines.size();
    if (!fits_capacity(capacity, count)) {
        return invalid_argument("invalid Hough line evidence buffer capacity");
    }
    if (count > 0 && lines == nullptr) {
        return invalid_argument("null Hough line evidence buffer");
    }
    std::copy(result->lines.begin(), result->lines.end(), lines);
    return OPENCV_IMGPROC_OK;
}

// maximum_lines and threshold are not checked here: OpenCV 4.1.0, 4.10.0,
// and 5.0.0 reject lines_max <= 0 and threshold < 0 before allocating the
// accumulator or running the vote loop, and threshold == 0 is safe natively.
opencv_imgproc_status
opencv_imgproc_hough_lines_point_set(
    const opencv_imgproc_point_f32 *points,
    int32_t point_count,
    int32_t maximum_lines,
    int32_t threshold,
    double min_rho,
    double max_rho,
    double rho_step,
    double min_theta,
    double max_theta,
    double theta_step,
    opencv_imgproc_hough_line_evidence_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough line evidence output pointer");
    }
    *out_result = nullptr;
    // ABI safety: the shim itself reads point_count records through points.
    // A nonnegative int32_t count also fits OpenCV's int point loop and the
    // shim's int32_t index.
    if (point_count < 0 || (point_count > 0 && points == nullptr)) {
        return invalid_argument("invalid Hough point-set point span");
    }

    try {
        const char *message = nullptr;
        point_set_geometry geometry{};
        if (!hough_point_set_geometry(
                min_rho, max_rho, rho_step, min_theta, max_theta, theta_step,
                geometry, &message)) {
            return invalid_argument(message);
        }
        // ABI safety: a nonfinite coordinate makes the native vote operand
        // NaN or infinite, which cvRound converts with undefined behavior
        // and which OpenCV 4.1 then uses as an unchecked accumulator index.
        for (int32_t index = 0; index < point_count; ++index) {
            if (!std::isfinite(points[index].x)
                || !std::isfinite(points[index].y)) {
                return invalid_argument(
                    "Hough point-set coordinates must be finite");
            }
        }
        if (!hough_point_set_votes_fit(
                points, point_count, min_theta, theta_step, geometry,
                &message)) {
            return invalid_argument(message);
        }

        // A CV_32FC2 collection: exactly the Point2f values the preflight
        // modelled (OpenCV copies its input to vector<Point2f>).
        std::vector<cv::Point2f> native_points;
        native_points.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            native_points.emplace_back(points[index].x, points[index].y);
        }

        auto *result = new opencv_imgproc_hough_line_evidence_handle;
        if (point_count == 0) {
            // An empty InputArray has no CV_32FC2 type, so OpenCV 4.10 fails
            // its internal copyTo; no points means no lines in any version.
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        }
        try {
            // Native output is Vec3d (votes, rho, theta).
            std::vector<cv::Vec3d> native;
            cv::HoughLinesPointSet(
                native_points, native, maximum_lines, threshold, min_rho,
                max_rho, rho_step, min_theta, max_theta, theta_step);
            if (!fits_int32(native.size())) {
                delete result;
                return invalid_argument(
                    "Hough line evidence count exceeds C ABI range");
            }
            result->lines.reserve(native.size());
            for (const cv::Vec3d &line : native) {
                result->lines.push_back({line[1], line[2], line[0]});
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_hough_circles_with_votes(
    const opencv_core_mat_handle *source,
    double dp,
    double min_dist,
    int32_t canny_threshold,
    int32_t accumulator_threshold,
    int32_t radius_mode,
    int32_t min_radius,
    int32_t max_radius,
    opencv_imgproc_hough_circle_evidence_handle **out_result)
{
    clear_error();

    if (out_result == nullptr) {
        return invalid_argument("null Hough circle evidence output pointer");
    }
    *out_result = nullptr;
    // ABI safety: in centers-only mode OpenCV 4.1.0, 4.10.0, and 5.0.0
    // GetCircleCenters(Vec4f) stores the accumulator index (float)center in
    // the fourth component; publishing it through this vote-bearing record
    // would present an index as a vote count.
    if (radius_mode != OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC
        && radius_mode != OPENCV_IMGPROC_HOUGH_RADIUS_EXPLICIT) {
        return invalid_argument(
            "vote-bearing Hough circles require a radius-finding mode");
    }

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid source Mat");
        }

        const char *message = nullptr;
        std::int64_t rows = 0;
        std::int64_t cols = 0;
        if (!hough_source_valid(*src, rows, cols, &message)
            || !hough_circles_preflight(
                rows, cols, dp, min_dist, canny_threshold,
                accumulator_threshold, radius_mode, min_radius, max_radius,
                &message)) {
            return invalid_argument(message);
        }

        cv::Mat snapshot = src->clone();
        const int native_max_radius =
            radius_mode == OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC
                ? 0
                : static_cast<int>(max_radius);
        auto *result = new opencv_imgproc_hough_circle_evidence_handle;
        try {
            // A vector<Vec4f> is a fixed CV_32FC4 output; with radius finding
            // GetCircle4f writes (x, y, radius, (float)accum).
            cv::HoughCircles(
                snapshot, result->circles, cv::HOUGH_GRADIENT, dp, min_dist,
                static_cast<double>(canny_threshold),
                static_cast<double>(accumulator_threshold),
                static_cast<int>(min_radius), native_max_radius);
            if (!fits_int32(result->circles.size())) {
                delete result;
                return invalid_argument(
                    "Hough circle evidence count exceeds C ABI range");
            }
            *out_result = result;
            return OPENCV_IMGPROC_OK;
        } catch (...) {
            delete result;
            throw;
        }
    } catch (...) {
        return translate_current_exception();
    }
}

void
opencv_imgproc_hough_circle_evidence_destroy(
    opencv_imgproc_hough_circle_evidence_handle *result)
{
    delete result;
}

opencv_imgproc_status
opencv_imgproc_hough_circle_evidence_count(
    const opencv_imgproc_hough_circle_evidence_handle *result,
    int32_t *out_count)
{
    clear_error();
    if (result == nullptr || out_count == nullptr) {
        return invalid_argument(
            "invalid Hough circle evidence count arguments");
    }
    if (!fits_int32(result->circles.size())) {
        return invalid_argument(
            "Hough circle evidence count exceeds C ABI range");
    }
    *out_count = static_cast<int32_t>(result->circles.size());
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_hough_circle_evidence_copy(
    const opencv_imgproc_hough_circle_evidence_handle *result,
    opencv_imgproc_hough_circle_evidence *circles,
    int32_t capacity)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("invalid Hough circle evidence result");
    }
    const std::size_t count = result->circles.size();
    if (!fits_capacity(capacity, count)) {
        return invalid_argument(
            "invalid Hough circle evidence buffer capacity");
    }
    if (count > 0 && circles == nullptr) {
        return invalid_argument("null Hough circle evidence buffer");
    }
    for (std::size_t index = 0; index < count; ++index) {
        const cv::Vec4f &circle = result->circles[index];
        circles[index].x = circle[0];
        circles[index].y = circle[1];
        circles[index].radius = circle[2];
        circles[index].votes = circle[3];
    }
    return OPENCV_IMGPROC_OK;
}

opencv_imgproc_status
opencv_imgproc_flood_fill(
    opencv_core_mat_handle *image,
    int32_t seed_x,
    int32_t seed_y,
    const opencv_imgproc_scalar4 *new_value,
    const opencv_imgproc_scalar4 *lower_difference,
    const opencv_imgproc_scalar4 *upper_difference,
    int32_t connectivity,
    int32_t range_mode,
    int32_t *pixel_count,
    opencv_imgproc_rect_i32 *bounds)
{
    return opencv_imgproc_flood_fill_masked_impl(
        image, nullptr, false, seed_x, seed_y, new_value, lower_difference,
        upper_difference, connectivity, range_mode, 1, 0, pixel_count,
        bounds);
}

opencv_imgproc_status
opencv_imgproc_flood_fill_masked(
    opencv_core_mat_handle *image,
    opencv_core_mat_handle *mask,
    int32_t seed_x,
    int32_t seed_y,
    const opencv_imgproc_scalar4 *new_value,
    const opencv_imgproc_scalar4 *lower_difference,
    const opencv_imgproc_scalar4 *upper_difference,
    int32_t connectivity,
    int32_t range_mode,
    int32_t mask_fill_value,
    uint8_t mask_only,
    int32_t *pixel_count,
    opencv_imgproc_rect_i32 *bounds)
{
    return opencv_imgproc_flood_fill_masked_impl(
        image, mask, true, seed_x, seed_y, new_value, lower_difference,
        upper_difference, connectivity, range_mode, mask_fill_value,
        mask_only, pixel_count, bounds);
}

opencv_imgproc_status
opencv_imgproc_mat_storage_overlap(
    const opencv_core_mat_handle *first,
    const opencv_core_mat_handle *second,
    uint8_t *overlap)
{
    clear_error();

    if (overlap == nullptr) {
        return invalid_argument("overlap output is null");
    }
    *overlap = 0;

    try {
        const cv::Mat *first_mat = nullptr;
        const cv::Mat *second_mat = nullptr;
        if (opencv_core_module_input_mat(first, &first_mat) != OPENCV_CORE_OK
            || first_mat == nullptr) {
            return invalid_argument("invalid first Mat");
        }
        if (opencv_core_module_input_mat(second, &second_mat) != OPENCV_CORE_OK
            || second_mat == nullptr) {
            return invalid_argument("invalid second Mat");
        }
        *overlap = mat_storage_overlaps(*first_mat, *second_mat) ? 1 : 0;
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_watershed(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *markers)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid watershed source");
        }
        cv::Mat *labels = nullptr;
        if (opencv_core_module_output_mat(markers, &labels) != OPENCV_CORE_OK
            || labels == nullptr) {
            return invalid_argument("invalid watershed markers");
        }
        const char *message = watershed_preflight(*src, *labels);
        if (message != nullptr) {
            return invalid_argument(message);
        }
        cv::watershed(*src, *labels);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_grabcut(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *mask,
    opencv_core_mat_handle *background_model,
    opencv_core_mat_handle *foreground_model,
    int32_t rect_x,
    int32_t rect_y,
    int32_t rect_width,
    int32_t rect_height,
    int32_t iteration_count,
    int32_t mode)
{
    clear_error();

    try {
        const cv::Mat *src = nullptr;
        if (opencv_core_module_input_mat(source, &src) != OPENCV_CORE_OK
            || src == nullptr) {
            return invalid_argument("invalid GrabCut source");
        }
        cv::Mat *labels = nullptr;
        if (opencv_core_module_output_mat(mask, &labels) != OPENCV_CORE_OK
            || labels == nullptr) {
            return invalid_argument("invalid GrabCut mask");
        }
        cv::Mat *background = nullptr;
        cv::Mat *foreground = nullptr;
        if (opencv_core_module_output_mat(background_model, &background)
                != OPENCV_CORE_OK
            || background == nullptr
            || opencv_core_module_output_mat(foreground_model, &foreground)
                != OPENCV_CORE_OK
            || foreground == nullptr) {
            return invalid_argument("invalid GrabCut model");
        }

        int opencv_mode = 0;
        if (!grabcut_mode(mode, opencv_mode)) {
            return invalid_argument("invalid GrabCut mode");
        }
        if (iteration_count <= 0) {
            // ABI safety: with iterCount <= 0 OpenCV returns right after
            // initGMMs, publishing a mask and models that were never
            // segmented (a partially initialized state) as success.
            return invalid_argument("GrabCut iteration count must be positive");
        }
        if (mode == OPENCV_IMGPROC_GRABCUT_EVAL_FREEZE_MODEL
            && iteration_count != 1) {
            // ABI safety: OpenCV silently rewrites iterCount to 1 in this
            // mode, so any other count would report success for work that
            // was never performed.
            return invalid_argument(
                "frozen-model GrabCut performs exactly one iteration");
        }

        const char *message =
            grabcut_state_preflight(src, labels, background, foreground);
        if (message == nullptr) {
            message = grabcut_mode_preflight(
                mode, *src, *labels, *background, *foreground, rect_x, rect_y,
                rect_width, rect_height);
        }
        if (message != nullptr) {
            return invalid_argument(message);
        }

        const cv::Rect rect(
            static_cast<int>(rect_x), static_cast<int>(rect_y),
            static_cast<int>(rect_width), static_cast<int>(rect_height));
        cv::grabCut(
            *src, *labels, rect, *background, *foreground,
            static_cast<int>(iteration_count), opencv_mode);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_calc_hist(
    const opencv_core_mat_handle *source,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram)
{
    return calc_hist_impl(
        source, nullptr, false, dimensions, dimension_count, histogram);
}

opencv_imgproc_status
opencv_imgproc_calc_hist_masked(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *mask,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram)
{
    return calc_hist_impl(
        source, mask, true, dimensions, dimension_count, histogram);
}

opencv_imgproc_status
opencv_imgproc_compare_hist(
    const opencv_core_mat_handle *left,
    const opencv_core_mat_handle *right,
    int32_t method,
    double *result)
{
    clear_error();
    if (result == nullptr) {
        return invalid_argument("histogram comparison result must not be null");
    }
    *result = 0.0;

    try {
        const cv::Mat *first = nullptr;
        const cv::Mat *second = nullptr;
        if (opencv_core_module_input_mat(left, &first) != OPENCV_CORE_OK
            || first == nullptr
            || opencv_core_module_input_mat(right, &second) != OPENCV_CORE_OK
            || second == nullptr) {
            return invalid_argument("invalid histogram");
        }
        int opencv_method = 0;
        if (!to_opencv_histogram_comparison(method, opencv_method)) {
            return invalid_argument("unsupported histogram comparison method");
        }
        if (first->empty() || second->empty()) {
            // ABI safety: NAryMatIterator skips arrays without data and
            // compareHist then dereferences planes of an empty Mat.
            return invalid_argument("histograms must be nonempty");
        }
        if (first->type() != CV_32FC1 || second->type() != CV_32FC1
            || first->size != second->size) {
            // ABI safety: compareHist walks both planes with the first
            // array's length; a smaller second histogram is over-read.
            return invalid_argument(
                "histograms must be Float32 C1 with identical shape");
        }
        if (first->total() > native_int_max) {
            // ABI safety: compareHist forms each plane length as
            // int rows * cols * channels.
            return invalid_argument("histogram element count exceeds native int");
        }
        const cv::Mat a = first->isContinuous() ? *first : first->clone();
        const cv::Mat b = second->isContinuous() ? *second : second->clone();
        *result = cv::compareHist(a, b, opencv_method);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        *result = 0.0;
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_calc_back_project(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *histogram,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    double scale,
    opencv_core_mat_handle *destination)
{
    clear_error();

    try {
        cv::Mat *dst = nullptr;
        if (opencv_core_module_output_mat(destination, &dst) != OPENCV_CORE_OK
            || dst == nullptr) {
            return invalid_argument("invalid back projection destination");
        }
        const cv::Mat *hist = nullptr;
        if (opencv_core_module_input_mat(histogram, &hist) != OPENCV_CORE_OK
            || hist == nullptr) {
            return invalid_argument("invalid back projection histogram");
        }
        const cv::Mat *src = nullptr;
        const cv::Mat *unused_mask = nullptr;
        native_histogram_request request;
        const char *message = histogram_inputs(
            source, nullptr, false, dimensions, dimension_count, src,
            unused_mask, request);
        if (message != nullptr) {
            return invalid_argument(message);
        }
        if (hist->type() != CV_32FC1
            || !histogram_shape_matches(*hist, request.sizes)) {
            // ABI safety: calcBackProj_ reads bins through hist.step with
            // indices bounded only by the supplied bin counts, and
            // reinterprets the data as float.
            return invalid_argument(
                "back projection histogram must be Float32 C1 matching the"
                " dimension bin counts");
        }
        if (!std::isfinite(scale) || std::fabs(scale) > FLT_MAX) {
            // ABI safety: calcBackProject narrows scale to float, which is
            // undefined for values outside the float range.
            return invalid_argument(
                "back projection scale must be finite in the float range");
        }

        float native_scale = 1.0f;
        cv::Mat native = back_project_histogram(
            *hist, src->depth(), static_cast<float>(scale), native_scale);
        if (dimension_count == 2
            && (request.sizes[0] == 1 || request.sizes[1] == 1)) {
            // OpenCV treats any 2-D histogram with a unit axis as 1-D (4.x:
            // size[1] == 1; 5.0: rows or cols == 1) and would drop the
            // second channel. A trailing one-bin axis that repeats the first
            // dimension keeps both channels and filters nothing extra.
            const int sizes[3] = {request.sizes[0], request.sizes[1], 1};
            native = native.reshape(1, 3, sizes);
            request.channels.push_back(request.channels[0]);
            request.ranges.push_back(request.ranges[0]);
        }
        cv::Mat result;
        cv::calcBackProject(
            src, 1, request.channels.data(), native, result,
            request.ranges.data(), native_scale, true);
        *dst = result;
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

} // extern "C"
