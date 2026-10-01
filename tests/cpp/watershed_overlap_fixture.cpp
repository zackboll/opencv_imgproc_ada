#include "opencv_core_module_bridge.hpp"

#include <cstddef>
#include <cstdint>
#include <exception>
#include <limits>
#include <opencv2/core.hpp>
#include <utility>

// Test-only fixture: both headers remain owned by OpenCV.Core. The caller
// keeps the markers alive until the aliased source is no longer used.
extern "C" int32_t opencv_imgproc_test_overlap_markers(
    const opencv_core_mat_handle *markers_handle,
    opencv_core_mat_handle *source_handle) noexcept
{
    try {
        const cv::Mat *markers = nullptr;
        cv::Mat *source = nullptr;
        if (markers_handle == nullptr || source_handle == nullptr ||
            opencv_core_module_input_mat(markers_handle, &markers) !=
                OPENCV_CORE_OK ||
            opencv_core_module_output_mat(source_handle, &source) !=
                OPENCV_CORE_OK ||
            markers == nullptr || source == nullptr ||
            markers->dims != 2 || markers->rows <= 0 || markers->cols <= 0 ||
            markers->type() != CV_32SC1 || markers->data == nullptr ||
            source->dims != 2 || source->rows != markers->rows ||
            source->cols != markers->cols || source->type() != CV_8UC3) {
            return 1;
        }

        const auto columns = static_cast<std::size_t>(markers->cols);
        if (columns > std::numeric_limits<std::size_t>::max() / 4 ||
            columns > std::numeric_limits<std::size_t>::max() / 3 ||
            markers->step[0] < columns * 4 ||
            markers->step[0] < columns * 3 ||
            markers->step[0] > std::numeric_limits<std::size_t>::max() /
                                   static_cast<std::size_t>(markers->rows)) {
            return 1;
        }

        // The fresh header aliases exactly the original allocation: no pixel
        // allocation, copy, or ownership transfer. Source has its own header.
        cv::Mat alias(markers->rows, markers->cols, CV_8UC3,
                      markers->data, markers->step[0]);
        *source = std::move(alias);
        return source->data == markers->data &&
                       source->step[0] == markers->step[0]
                   ? 0
                   : 1;
    } catch (const std::exception &) {
        return 1;
    } catch (...) {
        return 1;
    }
}