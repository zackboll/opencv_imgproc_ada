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

} // extern "C"
