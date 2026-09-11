#include "opencv_imgproc_shim.h"
#include "opencv_core_module_bridge.hpp"

#include <opencv2/imgproc.hpp>

#include <cstdio>
#include <cmath>
#include <exception>
#include <limits>

struct opencv_imgproc_contours_handle {
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
};

namespace {

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

bool to_opencv_color_conversion(
    int32_t conversion,
    int &opencv_conversion) noexcept
{
    switch (conversion) {
    case OPENCV_IMGPROC_COLOR_BGR_TO_GRAY:
        opencv_conversion = cv::COLOR_BGR2GRAY;
        return true;

    default:
        return false;
    }
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

        // ABI safety: reject malformed signed C dimensions before they reach
        // cv::Size and OpenCV's kernel-allocation arithmetic.
        if (kernel_width <= 0) {
            return invalid_argument("morphology kernel width must be positive");
        }

        if (kernel_height <= 0) {
            return invalid_argument("morphology kernel height must be positive");
        }

        // ABI safety: reject malformed signed C iteration counts before they
        // reach OpenCV's repeated-operation control flow.
        if (iterations <= 0) {
            return invalid_argument("morphology iterations must be positive");
        }

        int opencv_shape = 0;

        if (!to_opencv_morphology_shape(shape, opencv_shape)) {
            return invalid_argument("unsupported morphology shape");
        }

        int opencv_border = 0;

        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported morphology border");
        }

        const cv::Mat kernel = cv::getStructuringElement(
            opencv_shape,
            cv::Size(
                static_cast<int>(kernel_width),
                static_cast<int>(kernel_height)));

        if (operation == morphology_operation::erosion) {
            cv::erode(
                *src,
                *dst,
                kernel,
                cv::Point(-1, -1),
                static_cast<int>(iterations),
                opencv_border);
        } else {
            cv::dilate(
                *src,
                *dst,
                kernel,
                cv::Point(-1, -1),
                static_cast<int>(iterations),
                opencv_border);
        }

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
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

} // namespace

extern "C" {

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

        int opencv_conversion = 0;

        if (!to_opencv_color_conversion(
                conversion,
                opencv_conversion)) {
            return invalid_argument(
                "unsupported color conversion");
        }

        cv::cvtColor(*src, *dst, opencv_conversion);

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

        // ABI safety: reject malformed signed C dimensions before they reach
        // cv::Size and OpenCV's kernel-allocation arithmetic.
        if (kernel_width <= 0) {
            return invalid_argument("morphology kernel width must be positive");
        }

        if (kernel_height <= 0) {
            return invalid_argument("morphology kernel height must be positive");
        }

        // ABI safety: reject malformed signed C iteration counts before they
        // reach OpenCV's repeated-operation control flow.
        if (iterations <= 0) {
            return invalid_argument("morphology iterations must be positive");
        }

        int opencv_operation = 0;

        if (!to_opencv_morphology_operation(operation, opencv_operation)) {
            return invalid_argument("unsupported morphology operation");
        }

        int opencv_shape = 0;

        if (!to_opencv_morphology_shape(shape, opencv_shape)) {
            return invalid_argument("unsupported morphology shape");
        }

        int opencv_border = 0;

        if (!to_opencv_border(border, opencv_border)) {
            return invalid_argument("unsupported morphology border");
        }

        const cv::Mat kernel = cv::getStructuringElement(
            opencv_shape,
            cv::Size(
                static_cast<int>(kernel_width),
                static_cast<int>(kernel_height)));

        cv::morphologyEx(
            *src,
            *dst,
            opencv_operation,
            kernel,
            cv::Point(-1, -1),
            static_cast<int>(iterations),
            opencv_border);

        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
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
opencv_imgproc_contour_area(
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    int32_t oriented,
    double *out_area)
{
    clear_error();
    if (out_area == nullptr) {
        return invalid_argument("null contour area output pointer");
    }
    *out_area = 0.0;
    if (point_count < 0) {
        return invalid_argument("contour point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (oriented != 0 && oriented != 1) {
        return invalid_argument("contour oriented selector must be zero or one");
    }
    if (point_count == 0) {
        return OPENCV_IMGPROC_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        *out_area = cv::contourArea(contour, oriented != 0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_imgproc_status
opencv_imgproc_arc_length(
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    int32_t closed,
    double *out_length)
{
    clear_error();
    if (out_length == nullptr) {
        return invalid_argument("null arc length output pointer");
    }
    *out_length = 0.0;
    if (point_count < 0) {
        return invalid_argument("arc length point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (closed != 0 && closed != 1) {
        return invalid_argument("arc length closed selector must be zero or one");
    }
    if (point_count == 0) {
        return OPENCV_IMGPROC_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        *out_length = cv::arcLength(contour, closed != 0);
        return OPENCV_IMGPROC_OK;
    } catch (...) {
        return translate_current_exception();
    }
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

} // extern "C"
