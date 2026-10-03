// Compile the real shim in this standalone test, not a model of publication.
// Only this test translation unit can select the historical version branch;
// the linked OpenCV remains the installed runtime. No production override.
#include <opencv2/core/version.hpp>
#include <opencv2/imgproc.hpp>
#include "opencv_core_module_bridge.hpp"
// Load native headers with their real version first; select only shim guards.
#ifdef OPENCV_IMGPROC_TEST_LEGACY_BAYER_GRAY
#undef CV_VERSION_MAJOR
#undef CV_VERSION_MINOR
#undef CV_VERSION_REVISION
#define CV_VERSION_MAJOR 4
#define CV_VERSION_MINOR 5
#define CV_VERSION_REVISION 4
#endif
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"

#include <iostream>
#include <stdexcept>

namespace {

void require(bool condition, const char *message)
{
    if (!condition)
        throw std::runtime_error(message);
}

// Real Core-owned wrappers; borrowed native pointers are used only in tests.
struct test_mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *mat = nullptr;

    explicit test_mat(const cv::Mat &value)
    {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK,
                "Core wrapper allocation");
        if (opencv_core_module_output_mat(handle, &mat) != OPENCV_CORE_OK) {
            opencv_core_mat_destroy(handle);
            throw std::runtime_error("Core output bridge");
        }
        *mat = value;
    }

    test_mat(const test_mat &) = delete;
    test_mat &operator=(const test_mat &) = delete;
    ~test_mat() { opencv_core_mat_destroy(handle); }
};

void equal(const cv::Mat &a, const cv::Mat &b, const char *message)
{
    require(a.size() == b.size() && a.type() == b.type(), message);
    require(cv::norm(a, b, cv::NORM_INF) == 0, message);
}

void constant_gray(const cv::Mat &source, const cv::Mat &result,
                   uint16_t expected)
{
    require(result.size() == source.size() && result.type() == CV_16UC1,
            "UInt16 C1 Gray geometry");
    for (int y = 0; y < result.rows; ++y)
        for (int x = 0; x < result.cols; ++x)
            require(result.at<uint16_t>(y, x) == expected,
                    "native constant luminance including borders");
}

void regression()
{
    for (int32_t pattern = 0; pattern < 4; ++pattern) {
        test_mat source(cv::Mat(5, 6, CV_16UC1, cv::Scalar(65535)));
        test_mat destination(cv::Mat(2, 3, CV_8UC1, cv::Scalar(71)));
        const cv::Mat before = source.mat->clone();
        const cv::Mat sentinel = destination.mat->clone();
        const auto *old_data = destination.mat->data;
        const auto status = opencv_imgproc_demosaic_bayer_gray(
            source.handle, destination.handle, pattern);
        equal(*source.mat, before, "bright source unchanged");

#if CV_VERSION_MAJOR == 4 && \
    (CV_VERSION_MINOR < 5 || \
     (CV_VERSION_MINOR == 5 && CV_VERSION_REVISION < 5))
        require(status == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "legacy bright Gray rejected before native demosaicing");
        require(std::strstr(opencv_imgproc_last_error_message(),
                            "legacy OpenCV safe luminance range") != nullptr,
                "legacy diagnostic");
        equal(*destination.mat, sentinel, "raw destination atomicity");
        require(destination.mat->data == old_data,
                "rejection retains destination storage");
        require(opencv_imgproc_demosaic_bayer_gray(
                    source.handle, source.handle, pattern) ==
                    OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "same-handle rejection");
        equal(*source.mat, before, "same-handle source preserved");
#else
        (void)old_data;
        require(status == OPENCV_IMGPROC_OK,
                "fixed native implementation accepts bright UInt16 Gray");
        constant_gray(*source.mat, *destination.mat, 65535);
#endif
        source.mat->setTo(55825); // Exact four-green sum 223300.
        const cv::Mat safe_before = source.mat->clone();
        require(opencv_imgproc_demosaic_bayer_gray(
                    source.handle, destination.handle, pattern) ==
                    OPENCV_IMGPROC_OK,
                "valid boundary call succeeds after rejection");
        constant_gray(*source.mat, *destination.mat, 55825);
        equal(*source.mat, safe_before, "safe boundary source unchanged");

#if CV_VERSION_MAJOR == 4 && \
    (CV_VERSION_MINOR < 5 || \
     (CV_VERSION_MINOR == 5 && CV_VERSION_REVISION < 5))
        // First unsafe sum, at the first executed non-green center.
        const int x = (pattern == 0 || pattern == 2) ? 1 : 2;
        source.mat->at<uint16_t>(0, x) = 55826;
        const cv::Mat unsafe_before = source.mat->clone();
        const cv::Mat previous_result = destination.mat->clone();
        require(opencv_imgproc_demosaic_bayer_gray(
                    source.handle, destination.handle, pattern) ==
                    OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "sum 223301 raw rejection");
        equal(*source.mat, unsafe_before, "first unsafe source preserved");
        equal(*destination.mat, previous_result,
              "first unsafe destination preserved");
        source.mat->at<uint16_t>(0, x) = 55825;
        require(opencv_imgproc_demosaic_bayer_gray(
                    source.handle, destination.handle, pattern) ==
                    OPENCV_IMGPROC_OK,
                "recovery from first unsafe sum");

        // Full-range R/B samples do not enter the four-green multiplication.
        for (int y = 0; y < source.mat->rows; ++y)
            for (int col = 0; col < source.mat->cols; ++col)
                if ((y + col) % 2 == pattern % 2)
                    source.mat->at<uint16_t>(y, col) = 65535;
        require(opencv_imgproc_demosaic_bayer_gray(
                    source.handle, destination.handle, pattern) ==
                    OPENCV_IMGPROC_OK,
                "no conservative per-pixel cap");
#endif

        // A parent full of unsafe crosses must not affect a safe logical ROI.
        cv::Mat parent(7, 8, CV_16UC1, cv::Scalar(65535));
        test_mat region(parent(cv::Rect(1, 1, 5, 5)));
        region.mat->setTo(55825);
        const cv::Mat parent_before = parent.clone();
        require(opencv_imgproc_demosaic_bayer_gray(
                    region.handle, destination.handle, pattern) ==
                    OPENCV_IMGPROC_OK,
                "packed Region scan excludes parent storage");
        constant_gray(*region.mat, *destination.mat, 55825);
        equal(parent, parent_before, "Region and parent preserved");

        // The legacy restriction must not spill into color/alpha or UInt8.
        source.mat->setTo(65535);
        test_mat other(cv::Mat{});
        for (int32_t method : {int32_t{0}, int32_t{2}})
            require(opencv_imgproc_demosaic_bayer(
                        source.handle, other.handle, pattern, method, 0) ==
                        OPENCV_IMGPROC_OK,
                    "bright UInt16 color is unaffected");
        require(opencv_imgproc_demosaic_bayer_alpha(
                    source.handle, other.handle, pattern, 0) ==
                    OPENCV_IMGPROC_OK,
                "bright UInt16 alpha is unaffected");
        test_mat byte_source(cv::Mat(5, 6, CV_8UC1, cv::Scalar(255)));
        require(opencv_imgproc_demosaic_bayer_gray(
                    byte_source.handle, other.handle, pattern) ==
                    OPENCV_IMGPROC_OK,
                "UInt8 Gray is unaffected");
    }
}

} // namespace

int main()
{
    try {
        regression();
#ifdef OPENCV_IMGPROC_TEST_LEGACY_BAYER_GRAY
        std::cout << "Legacy branch: rejection, atomicity, recovery, "
                     "ROI PASS\n";
#else
        std::cout << "Installed OpenCV " << CV_VERSION
                  << ": UInt16 Gray regression and preservation PASS\n";
#endif
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}