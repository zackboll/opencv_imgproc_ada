// Exercise the production shim, including allocation-free arithmetic guards.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <iomanip>
#include <stdexcept>

namespace {
void require(bool value, const char *message) {
    if (!value) throw std::runtime_error(message);
}
struct Mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *value = nullptr;
    explicit Mat(const cv::Mat &m) {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK, "create");
        require(opencv_core_module_output_mat(handle, &value) == OPENCV_CORE_OK,
                "resolve");
        *value = m;
    }
    ~Mat() { opencv_core_mat_destroy(handle); }
    Mat(const Mat &) = delete;
    Mat &operator=(const Mat &) = delete;
};
// Fixed before qualification: absolute bound 2^-19 * active * 255^2.
// Two Float32 correlation roundings and the final subtract/add account for
// cancellation error; this is a bounded regression policy, not a theorem for
// every DFT backend. No tolerance is increased in response to observations.
void run(const std::string &id, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m, bool exact = false) {
    Mat source(s), templ(t), mask(m), result(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    const auto sb = s.clone(), tb = t.clone(), mb = m.clone();
    require(opencv_imgproc_match_template_masked(source.handle, templ.handle,
        mask.handle, result.handle, 0) == OPENCV_IMGPROC_OK,
        opencv_imgproc_last_error_message());
    const auto &r = *result.value;
    require(r.type() == CV_32FC1 && r.rows == s.rows - t.rows + 1 &&
        r.cols == s.cols - t.cols + 1 && !r.isSubmatrix(), "result layout");
    require(cv::norm(s, sb, cv::NORM_INF) == 0 &&
        cv::norm(t, tb, cv::NORM_INF) == 0 && cv::norm(m, mb, cv::NORM_INF) == 0,
        "input mutation");
    const int active = cv::countNonZero(m);
    std::cout << "CASE " << id << ' ' << s.rows << ' ' << s.cols << ' '
        << s.type() << ' ' << t.rows << ' ' << t.cols << ' ' << t.type() << ' '
        << m.rows << ' ' << m.cols << ' ' << m.type() << ' ' << active << ' '
        << r.rows << ' ' << r.cols << '\n';
    for (int y = 0; y < r.rows; ++y) for (int x = 0; x < r.cols; ++x) {
        std::uint64_t sum = 0;
        for (int v = 0; v < t.rows; ++v) for (int u = 0; u < t.cols; ++u)
            if (m.at<uchar>(v, u)) {
                const std::int64_t d = int(t.at<uchar>(v, u)) -
                    int(s.at<uchar>(y + v, x + u));
                sum += static_cast<std::uint64_t>(d * d);
            }
        const float score = r.at<float>(y, x);
        const double error = std::abs(double(score) - double(sum));
        require(std::isfinite(score) &&
            error <= (exact ? 0 : std::ldexp(double(active) * 65025, -19)),
            "independent UInt8 oracle mismatch");
        std::uint32_t bits = 0;
        std::memcpy(&bits, &score, sizeof(bits));
        std::cout << "SCORE " << std::hex << std::setw(8) << std::setfill('0')
            << bits << std::dec << '\n';
    }
    double minimum = 0;
    cv::Point location;
    cv::minMaxLoc(r, &minimum, nullptr, &location);
    if (id.find("-full-regions") != std::string::npos && t.total() > 1)
        require(location == cv::Point(2, 1), "known translated match");
    std::cout << "MIN " << location.x << ' ' << location.y << ' '
        << std::hexfloat << minimum << std::defaultfloat << '\n';
}
void guards() {
    using opencv_imgproc_masked_template::fits;
    require(fits(10000, 10000, 101, 99), "representable large geometry");
    require(fits(1, 1000000, 1, 1), "representable long row");
    require(!fits(INT_MAX, 2, 1, 1), "signed area");
    require(!fits(1, INT_MAX, 1, 1), "signed byte width");
    require(!fits(10, 10, 11, 1), "negative result extent");
    require(!opencv_imgproc_masked_template::span_fits(3, 2, SIZE_MAX), "stride");
    Mat a(cv::Mat(2, 2, CV_8U, cv::Scalar(1))), out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    require(opencv_imgproc_match_template_masked(nullptr, a.handle, a.handle,
        out.handle, 0) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "null handle");
    for (int selector : {-1, OPENCV_IMGPROC_TEMPLATE_CCOEFF_NORMED})
        require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
            out.handle, selector) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "unsupported selector");
    require(out.value->at<uchar>(0, 0) == 73, "failed publication");
    require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
        out.handle, OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED) == OPENCV_IMGPROC_OK,
        "normalized squared difference");
    require(out.value->type() == CV_32FC1 && out.value->rows == 1 &&
        out.value->cols == 1 && std::isfinite(out.value->at<float>(0, 0)),
        "normalized squared difference result");
    require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
        a.handle, 0) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "identity");
    require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
        out.handle, 0) == OPENCV_IMGPROC_OK, "recovery");
    Mat bad(cv::Mat(2, 2, CV_32F, cv::Scalar(1)));
    for (int position = 0; position < 3; ++position) {
        require(opencv_imgproc_match_template_masked(
            position == 0 ? bad.handle : a.handle,
            position == 1 ? bad.handle : a.handle,
            position == 2 ? bad.handle : a.handle, out.handle, 0) ==
            OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "raw depth");
    }
    Mat wrong_mask(cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
    require(opencv_imgproc_match_template_masked(a.handle, a.handle,
        wrong_mask.handle, out.handle, 0) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
        "raw mask size");
    require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
        nullptr, 0) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "null output");
    // Distinct headers sharing data are legal; publish into fresh storage.
    Mat shared(*a.value);
    const auto old_data = a.value->data;
    require(opencv_imgproc_match_template_masked(a.handle, a.handle, a.handle,
        shared.handle, 0) == OPENCV_IMGPROC_OK, "shared destination storage");
    require(shared.value->data != old_data && a.value->data == old_data &&
        a.value->at<uchar>(0, 0) == 1, "fresh output/input preservation");
}
}
int main() {
    try {
        require(cv::getVersionString() == CV_VERSION, "header/runtime mismatch");
        std::cout << "VERSION " << CV_VERSION << '\n';
        guards();
        for (const auto &size : {cv::Size(1, 1), cv::Size(3, 1), cv::Size(1, 4),
                cv::Size(3, 3), cv::Size(4, 2), cv::Size(9, 7), cv::Size(31, 27)}) {
            cv::Mat parent(size.height + 8, size.width + 11, CV_8U);
            for (int y = 0; y < parent.rows; ++y)
                for (int x = 0; x < parent.cols; ++x)
                    parent.at<uchar>(y, x) = uchar((y * 37 + x * 71 + y * x * 13) % 256);
            cv::Mat source = parent(cv::Rect(1, 1, size.width + 6, size.height + 5));
            cv::Mat templ = parent(cv::Rect(3, 2, size.width, size.height));
            cv::Mat mask_parent(size.height + 2, size.width + 3, CV_8U, cv::Scalar(255));
            cv::Mat mask = mask_parent(cv::Rect(1, 1, size.width, size.height));
            const std::string id = std::to_string(size.width) + "x" + std::to_string(size.height);
            run(id + "-full-regions", source, templ, mask);
            for (int y = 0; y < mask.rows; ++y) for (int x = 0; x < mask.cols; ++x)
                mask.at<uchar>(y, x) = (x + y) % 3 == 0 ? 0 :
                    ((x + y) % 3 == 1 ? 1 : 127);
            run(id + "-binary", source, templ, mask);
            cv::Mat corrupted = templ.clone();
            corrupted.at<uchar>(0, 0) ^= 255;
            mask.at<uchar>(0, 0) = 0;
            run(id + "-excluded-template", source, corrupted, mask);
            mask.setTo(0);
            run(id + "-zero", source, templ, mask, true);
            mask.setTo(255);
            run(id + "-equal", templ, templ, mask);
        }
        run("max-difference", cv::Mat(1, 1, CV_8U, cv::Scalar(255)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(0)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(127)), true);
        run("one-row", cv::Mat(1, 9, CV_8U, cv::Scalar(9)),
            cv::Mat(1, 3, CV_8U, cv::Scalar(2)),
            cv::Mat(1, 3, CV_8U, cv::Scalar(1)), true);
        run("one-column", cv::Mat(9, 1, CV_8U, cv::Scalar(9)),
            cv::Mat(4, 1, CV_8U, cv::Scalar(2)),
            cv::Mat(4, 1, CV_8U, cv::Scalar(255)), true);
        cv::Mat scene(1, 8, CV_8U, cv::Scalar(70));
        const uchar pixels[] = {70, 10, 200, 255, 70, 20, 190, 0};
        std::memcpy(scene.ptr(), pixels, sizeof(pixels));
        cv::Mat landmark(1, 3, CV_8U), visibility(1, 3, CV_8U);
        landmark.at<uchar>(0, 0) = 10;
        landmark.at<uchar>(0, 1) = 200;
        landmark.at<uchar>(0, 2) = 0;
        visibility.at<uchar>(0, 0) = 1;
        visibility.at<uchar>(0, 1) = 127;
        visibility.at<uchar>(0, 2) = 0;
        run("distinctive-obscured-source", scene, landmark, visibility);
        landmark.at<uchar>(0, 2) = 127;
        run("distinctive-corrupted-template", scene, landmark, visibility);
        visibility.setTo(255);
        run("distractor-full-mask", scene, landmark, visibility);
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}