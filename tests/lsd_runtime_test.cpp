// Real production shim, Core-owned handles, and independent OpenCV oracles.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <stdexcept>

namespace {
int references = 0, rejections = 0;
void require(bool condition, const char *message) {
    if (!condition) throw std::runtime_error(message);
}
struct Mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *value = nullptr;
    explicit Mat(const cv::Mat &image = cv::Mat()) {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK, "Core create");
        require(opencv_core_module_output_mat(handle, &value) == OPENCV_CORE_OK,
                "Core bridge");
        *value = image;
    }
    ~Mat() { opencv_core_mat_destroy(handle); }
    Mat(const Mat &) = delete;
    Mat &operator=(const Mat &) = delete;
};
struct Result {
    opencv_imgproc_lsd_handle *handle = nullptr;
    ~Result() { opencv_imgproc_lsd_destroy(handle); }
};
[[maybe_unused]] void equal(const cv::Mat &a, const cv::Mat &b) {
    require(a.size() == b.size() && a.type() == b.type(), "oracle metadata");
    require(cv::norm(a, b, cv::NORM_INF) == 0, "oracle pixels");
    ++references;
}
void rejected(int32_t status) {
    require(status != OPENCV_IMGPROC_OK, "malformed ABI accepted");
    require(*opencv_imgproc_last_error_message(), "missing diagnostic");
    ++rejections;
}
int32_t detect(Mat &source, Result &result, int mode = 1,
               double scale = 1, double sigma = .6, double quant = 2,
               double angle = 22.5, int bins = 1024) {
    return opencv_imgproc_lsd_detect(source.handle, mode, scale, sigma,
        quant, angle, 0, .7, bins, &result.handle);
}
// Compile the enum-to-actual-signature call even on 4.1, but never execute its
// removed implementation there. This also verifies 4.x enum-to-int conversion.
[[maybe_unused]] cv::Ptr<cv::LineSegmentDetector> direct(int mode, double scale) {
    return cv::createLineSegmentDetector(
        static_cast<cv::LineSegmentDetectorModes>(mode), scale);
}
#if OPENCV_IMGPROC_HAS_LSD
void reference(Mat &source, int mode, double scale) {
    const cv::Mat before = source.value->clone();
    Result result;
    require(detect(source, result, mode, scale) == OPENCV_IMGPROC_OK,
            opencv_imgproc_last_error_message());
    int32_t count = -1;
    require(opencv_imgproc_lsd_count(result.handle, &count) == OPENCV_IMGPROC_OK,
            "count");
    std::vector<opencv_imgproc_lsd_segment> records(count);
    require(opencv_imgproc_lsd_copy(result.handle, records.data(), count) ==
            OPENCV_IMGPROC_OK, "copy");
    std::vector<cv::Vec4f> lines;
    std::vector<double> widths, precision;
    auto detector = direct(mode, scale);
    cv::Mat logical = source.value->clone();
    require(mode < 2 && scale == 1, "normal oracle must use portable contract");
    detector->detect(logical, lines, widths, precision);
    require(lines.size() == records.size() && widths.size() == records.size() &&
            precision.size() == records.size(), "oracle counts");
    for (size_t i = 0; i < records.size(); ++i) {
        const auto &r = records[i];
        require(r.x1 == lines[i][0] && r.y1 == lines[i][1] &&
                r.x2 == lines[i][2] && r.y2 == lines[i][3], "oracle endpoints");
        require(r.width == widths[i] && r.precision == precision[i],
                "oracle diagnostics");
        require(r.has_nfa == 0 && r.reserved == 0 && r.nfa == 0, "NFA unavailable");
        ++references;
    }
    equal(*source.value, before);
    Mat output;
    require(opencv_imgproc_lsd_render(source.handle, records.data(), count,
                                      output.handle) == OPENCV_IMGPROC_OK,
            "render");
    cv::Mat expected;
    cv::cvtColor(logical, expected, cv::COLOR_GRAY2BGR);
    if (count) detector->drawSegments(expected, lines);
    equal(*output.value, expected);
    rejected(opencv_imgproc_lsd_copy(result.handle, nullptr, count ? count : -1));
    if (count) rejected(opencv_imgproc_lsd_copy(result.handle, records.data(), count - 1));
    // Result data survives native handle and source changes.
    opencv_imgproc_lsd_destroy(result.handle);
    result.handle = nullptr;
    if (count) require(records[0].width == widths[0], "independent data");
}
void comparison(const std::vector<opencv_imgproc_lsd_segment> &a,
                const std::vector<opencv_imgproc_lsd_segment> &b) {
    Mat output;
    int32_t mismatch = -1, count_only = -1;
    require(opencv_imgproc_lsd_compare(128, 128, a.data(), int32_t(a.size()),
            b.data(), int32_t(b.size()), &mismatch, output.handle) ==
            OPENCV_IMGPROC_OK, "compare");
    require(opencv_imgproc_lsd_compare(128, 128, a.data(), int32_t(a.size()),
            b.data(), int32_t(b.size()), &count_only, nullptr) ==
            OPENCV_IMGPROC_OK && mismatch == count_only, "count-only compare");
    cv::Mat expected = cv::Mat::zeros(128, 128, CV_8UC3);
    std::vector<cv::Vec4f> av, bv;
    for (const auto &s : a) av.emplace_back(s.x1, s.y1, s.x2, s.y2);
    for (const auto &s : b) bv.emplace_back(s.x1, s.y1, s.x2, s.y2);
    // Explicit typed empty Mats avoid std::vector empty InputArray differences.
    cv::Mat am(int(av.size()), 1, CV_32FC4, av.data());
    cv::Mat bm(int(bv.size()), 1, CV_32FC4, bv.data());
    const int native = direct(1, 1)->compareSegments(cv::Size(128, 128), am, bm, expected);
    require(native == mismatch, "oracle mismatch count");
    ++references;
    equal(*output.value, expected);
}
#endif
}

int main(int argc, char **argv) {
    try {
        Mat source(cv::Mat::zeros(128, 128, CV_8UC1));
        Mat output(cv::Mat::ones(3, 3, CV_8UC3));
        Result result;
        int32_t count = 12;
        rejected(opencv_imgproc_lsd_count(nullptr, &count));
        require(count == 0, "count failure initialized");
        rejected(opencv_imgproc_lsd_count(nullptr, nullptr));
        rejected(opencv_imgproc_lsd_copy(nullptr, nullptr, -1));
        rejected(opencv_imgproc_lsd_detect(nullptr, 1, .8, .6, 2, 22.5, 0, .7,
                                          1024, nullptr));
#if !OPENCV_IMGPROC_HAS_LSD
        require(detect(source, result) == OPENCV_IMGPROC_ERROR_OPENCV,
                "explicit unsupported detector");
        require(result.handle == nullptr, "unsupported null result");
        require(opencv_imgproc_lsd_render(source.handle, nullptr, 0, output.handle)
                == OPENCV_IMGPROC_ERROR_OPENCV, "unsupported render");
        require(opencv_imgproc_lsd_compare(128, 128, nullptr, 0, nullptr, 0,
                &count, output.handle) == OPENCV_IMGPROC_ERROR_OPENCV,
                "unsupported compare");
        require(count == 0 && output.value->rows == 3, "unsupported atomicity");
        references += 3;
#else
        // Historical unsafe upstream reproductions are opt-in direct native
        // calls only. They cannot be reached by normal production-shim tests.
        if (argc == 2 && (std::strcmp(argv[1], "--unsafe-upstream-resize") == 0 ||
                         std::strcmp(argv[1], "--unsafe-upstream-advanced") == 0)) {
            cv::rectangle(*source.value, {20,20,80,80}, 255, 2);
            std::vector<cv::Vec4f> lines;
            std::vector<double> widths, precision, nfa;
            const bool advanced = std::strcmp(argv[1], "--unsafe-upstream-advanced") == 0;
            direct(advanced ? 2 : 1, advanced ? 1 : .8)->detect(
                *source.value, lines, widths, precision, nfa);
            std::cout << "Opt-in unsafe upstream reproduction returned\n";
            return 0;
        }
        require(argc == 1, "unknown campaign selector");
        for (int mode = 0; mode < 2; ++mode) {
                for (int pattern = 0; pattern < 6; ++pattern) {
                    source.value->setTo(0);
                    if (pattern == 1) cv::line(*source.value, {10,40}, {115,40}, 255, 2);
                    if (pattern == 2) cv::line(*source.value, {40,10}, {40,115}, 255, 2);
                    if (pattern == 3) cv::line(*source.value, {10,15}, {110,105}, 255, 2);
                    if (pattern == 4) cv::rectangle(*source.value, {20,20,80,80}, 255, 2);
                    if (pattern == 5) {
                        cv::line(*source.value, {10,30}, {115,30}, 255, 2);
                        cv::line(*source.value, {10,90}, {115,90}, 255, 2);
                    }
                    reference(source, mode, 1);
                }
        }
        // Independent references on small/adversarial geometry, varied
        // contrast and near-axis gradients. No global backend flags change.
        for (int mode = 0; mode < 2; ++mode)
            for (int size : {1, 2, 3, 7, 16, 31, 64, 129, 257})
                for (int contrast : {1, 17, 127, 255})
                    for (int pattern = 0; pattern < 5; ++pattern) {
                        Mat image(cv::Mat::zeros(size, size + 3, CV_8UC1));
                        if (pattern == 0) cv::line(*image.value, {0,size/2}, {size+2,size/2+1}, contrast);
                        if (pattern == 1) cv::line(*image.value, {size/2,0}, {size/2+1,size-1}, contrast);
                        if (pattern == 2) cv::rectangle(*image.value, {0,0,size+3,size}, contrast);
                        if (pattern == 3)
                            for (int y = 0; y < size; ++y)
                                for (int x = 0; x < size + 3; ++x)
                                    image.value->at<uchar>(y,x) = uchar(((x*17+y*31) % 5) * contrast / 4);
                        reference(image, mode, 1);
                    }
        cv::Mat parent = cv::Mat::zeros(170, 170, CV_8UC1);
        cv::rectangle(parent, {2,2,165,165}, 255, 2);
        Mat roi(parent(cv::Rect(20, 20, 128, 128)));
        require(!roi.value->isContinuous(), "ROI fixture");
        reference(roi, 1, 1);
        cv::line(*roi.value, {5,50}, {120,50}, 255, 2);
        reference(roi, 0, 1);
        const opencv_imgproc_lsd_segment horizontal{10.25f,30,90.5f,30,2,.125,0,0,0};
        const opencv_imgproc_lsd_segment vertical{50,10,50,90,2,.125,0,0,0};
        comparison({}, {});
        comparison({horizontal}, {});
        comparison({}, {vertical});
        comparison({horizontal}, {horizontal});
        comparison({horizontal}, {vertical});
        comparison({horizontal,vertical}, {vertical,horizontal});
        for (int bins : {0, -1, INT_MAX}) rejected(detect(source, result, 1, 1, .6, 2, 22.5, bins));
        for (double scale : {.8, .5, 1.000001, 0.0, -1.0, 1e-100, DBL_MAX,
                              std::numeric_limits<double>::quiet_NaN()})
            rejected(detect(source, result, 1, scale));
        rejected(detect(source, result, 2));
        // Null handle proves the envelope gate fires before bridge access,
        // detector construction or any potential rect_improve/rect_nfa call.
        rejected(opencv_imgproc_lsd_detect(nullptr, 2, 1, .6, 2, 22.5, 0, .7,
                                          1024, &result.handle));
        require(std::strstr(opencv_imgproc_last_error_message(), "portable LSD"),
                "Advanced must be rejected by pre-construction envelope");
        for (double sigma : {0.0, -1.0})
            rejected(detect(source, result, 1, 1, sigma));
        rejected(detect(source, result, 1, 1, .6, DBL_MAX, DBL_MIN));
        for (double angle : {0.0, 180.0, std::numeric_limits<double>::quiet_NaN()})
            rejected(detect(source, result, 1, 1, .6, 2, angle));
        for (double quant : {-1.0, std::numeric_limits<double>::infinity()})
            rejected(detect(source, result, 1, 1, .6, quant));
        rejected(detect(source, result, 3));
        rejected(opencv_imgproc_lsd_detect(nullptr, 1, 1, .6, 2, 22.5, 0, .7,
                                          1024, &result.handle));
        require(!result.handle, "failure null result");
        Mat empty;
        rejected(detect(empty, result));
        int sizes[] = {2,3,4};
        Mat volume(cv::Mat(3, sizes, CV_8UC1));
        rejected(detect(volume, result));
        // A real Core wrapper with an oversized header: reject before clone
        // or pixel access, without allocating a huge image.
        Mat large(cv::Mat(1, 1, CV_8UC1, cv::Scalar(0)));
        large.value->rows = INT_MAX;
        large.value->cols = 2;
        rejected(detect(large, result));
        auto unsafe = horizontal;
        for (float coordinate : {FLT_MAX, std::numeric_limits<float>::infinity(),
                                  std::numeric_limits<float>::quiet_NaN()}) {
            unsafe.x1 = coordinate;
            rejected(opencv_imgproc_lsd_render(source.handle, &unsafe, 1, output.handle));
        }
        rejected(opencv_imgproc_lsd_render(source.handle, nullptr, 1, output.handle));
        rejected(opencv_imgproc_lsd_render(source.handle, &horizontal, -1, output.handle));
        rejected(opencv_imgproc_lsd_render(source.handle, &horizontal, 1, source.handle));
        rejected(opencv_imgproc_lsd_compare(INT_MAX, INT_MAX, nullptr, 0, nullptr, 0, &count, output.handle));
        require(count == 0 && output.value->rows == 3, "failure atomicity");
        rejected(opencv_imgproc_lsd_compare(0, 128, nullptr, 0, nullptr, 0, &count, nullptr));
        rejected(opencv_imgproc_lsd_compare(128, 128, nullptr, 1, nullptr, 0, &count, nullptr));
        rejected(opencv_imgproc_lsd_compare(128, 128, nullptr, 0, nullptr, -1, &count, nullptr));
        rejected(opencv_imgproc_lsd_compare(128, 128, nullptr, 0, nullptr, 0, nullptr, nullptr));
        reference(source, 1, 1); // recovery
#endif
        (void)argc; (void)argv;
        std::cout << "OpenCV " << CV_VERSION << ": " << references
                  << " native reference assertions, " << rejections
                  << " expected ABI rejections; PASS\n";
    } catch (const std::exception &e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}