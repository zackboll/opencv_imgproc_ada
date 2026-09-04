#include "opencv_imgproc_shim.h"
#include "opencv_core_module_bridge.hpp"

#include <opencv2/imgproc.hpp>

#include <cstdio>
#include <exception>

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

} // extern "C"
