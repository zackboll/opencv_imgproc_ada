// Production-shim masked normalized SQDIFF corpus.
// Oracle ceiling max(1e-4, 4 ULP) and cross-version limits 1e-4 / 8 ULP
// were fixed before reading qualification output.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"

#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {
void require(bool value, const char *message) {
    if (!value)
        throw std::runtime_error(message);
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

struct Sums {
    std::uint64_t numer = 0, templ = 0, scene = 0;
};

Sums sums(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m, int y, int x) {
    Sums result;
    for (int v = 0; v < t.rows; ++v) {
        for (int u = 0; u < t.cols; ++u) {
            if (m.at<uchar>(v, u) == 0)
                continue;
            const auto tv = static_cast<std::uint64_t>(t.at<uchar>(v, u));
            const auto iv =
                static_cast<std::uint64_t>(s.at<uchar>(y + v, x + u));
            const std::uint64_t delta = tv > iv ? tv - iv : iv - tv;
            result.numer += delta * delta;
            result.templ += tv * tv;
            result.scene += iv * iv;
        }
    }
    return result;
}

int ulps(float left, float right) {
    std::uint32_t a = 0, b = 0;
    std::memcpy(&a, &left, 4);
    std::memcpy(&b, &right, 4);
    auto order = [](std::uint32_t bits) {
        return (bits & 0x80000000u) ? 0x80000000u - (bits & 0x7fffffffu)
                                     : bits + 0x80000000u;
    };
    const auto oa = order(a), ob = order(b);
    return static_cast<int>(oa > ob ? oa - ob : ob - oa);
}

const char *branch() {
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
    return "native";
#else
    return "compatibility";
#endif
}

void run(const std::string &id, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m) {
    Mat source(s), templ(t), mask(m);
    Mat result(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    const cv::Mat sb = s.clone(), tb = t.clone(), mb = m.clone();
    require(opencv_imgproc_match_template_masked(
                source.handle, templ.handle, mask.handle, result.handle,
                OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED) == OPENCV_IMGPROC_OK,
            opencv_imgproc_last_error_message());
    const cv::Mat &r = *result.value;
    require(r.type() == CV_32FC1 && r.rows == s.rows - t.rows + 1 &&
                r.cols == s.cols - t.cols + 1 && !r.isSubmatrix(),
            "result layout");
    require(cv::norm(s, sb, cv::NORM_INF) == 0 &&
                cv::norm(t, tb, cv::NORM_INF) == 0 &&
                cv::norm(m, mb, cv::NORM_INF) == 0,
            "input mutation");
    std::cout << "CASE " << id << ' ' << branch() << ' ' << s.rows << ' '
              << s.cols << ' ' << t.rows << ' ' << t.cols << ' '
              << cv::countNonZero(m) << ' ' << r.rows << ' ' << r.cols << '\n';
    int best_count = 0;
    float best = std::numeric_limits<float>::infinity();
    float second = best;
    cv::Point best_at(-1, -1);
    for (int y = 0; y < r.rows; ++y) {
        for (int x = 0; x < r.cols; ++x) {
            const Sums value = sums(s, t, m, y, x);
            const float score = r.at<float>(y, x);
            std::uint32_t bits = 0;
            std::memcpy(&bits, &score, 4);
            float reference = std::numeric_limits<float>::max();
            if (value.scene != 0) {
                const long double ideal =
                    static_cast<long double>(value.numer) /
                    std::sqrt(static_cast<long double>(value.templ) *
                              value.scene);
                reference = static_cast<float>(ideal);
                const float gap = std::fabs(score - reference);
                const float neighbor = std::nextafter(reference, 0.0f);
                const float step = std::fabs(reference - neighbor);
                require(std::isfinite(score), "positive-energy nonfinite");
                require(gap <= std::max(1.0e-4f, 4.0f * step), "oracle ceiling");
            } else {
                require(bits == 0x7f7fffffu, "zero-scene sentinel bits");
            }
            std::cout << "SCORE " << std::hex << std::setw(8) << std::setfill('0')
                      << bits << std::dec << ' ' << value.scene << ' '
                      << std::hexfloat << reference << std::defaultfloat << ' '
                      << ulps(score, reference) << '\n';
            if (score < best) {
                second = best;
                best = score;
                best_at = cv::Point(x, y);
                best_count = 1;
            } else if (score == best) {
                ++best_count;
            } else if (score < second) {
                second = score;
            }
        }
    }
    std::cout << "MIN " << best_at.x << ' ' << best_at.y << ' ' << best_count
              << ' ' << std::hexfloat << best << ' ' << second
              << std::defaultfloat << '\n';
}

void reject(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m) {
    Mat source(s), templ(t), mask(m);
    Mat out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    require(opencv_imgproc_match_template_masked(
                source.handle, templ.handle, mask.handle, out.handle,
                OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED) ==
                OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "expected rejection");
    require(out.value->at<uchar>(0, 0) == 73, "rejection atomicity");
}
}  // namespace

int main() {
    try {
        require(cv::getVersionString() == CV_VERSION, "header/runtime mismatch");
        std::cout << "VERSION " << CV_VERSION << ' ' << branch() << '\n';
        cv::Mat image(4, 5, CV_8U);
        for (int y = 0; y < 4; ++y)
            for (int x = 0; x < 5; ++x)
                image.at<uchar>(y, x) = static_cast<uchar>(20 + y * 3 + x);
        cv::Mat templ = image(cv::Rect(0, 0, 2, 2)).clone();
        cv::Mat full(2, 2, CV_8U, cv::Scalar(255));
        run("perfect", image, templ, full);
        cv::Mat sparse = full.clone();
        sparse.at<uchar>(0, 1) = 0;
        templ.at<uchar>(0, 1) = 200;
        run("sparse-excluded", image, templ, sparse);
        run("brighter", image * 2, templ, full);
        cv::Mat hi(2, 2, CV_8U, cv::Scalar(255));
        cv::Mat lo(2, 2, CV_8U, cv::Scalar(1));
        run("above-one", hi, lo, full);
        cv::Mat scene(1, 3, CV_8U, cv::Scalar(0));
        scene.at<uchar>(0, 2) = 8;
        cv::Mat row(1, 2, CV_8U);
        row.at<uchar>(0, 0) = 4;
        row.at<uchar>(0, 1) = 6;
        run("zero-beside-positive", scene, row,
            cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        run("one-pixel", cv::Mat(1, 1, CV_8U, cv::Scalar(9)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(3)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(7)));
        reject(image, cv::Mat(2, 2, CV_8U, cv::Scalar(0)), full);
        reject(image, templ, cv::Mat(2, 2, CV_8U, cv::Scalar(0)));
        Mat good(image), patch(templ), weight(full);
        Mat bad(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
        require(opencv_imgproc_match_template_masked(
                    good.handle, patch.handle, weight.handle, bad.handle,
                    OPENCV_IMGPROC_TEMPLATE_CCOEFF) != OPENCV_IMGPROC_OK,
                "coefficient selector");
        require(bad.value->at<uchar>(0, 0) == 73, "selector atomicity");
        require(opencv_imgproc_match_template_masked(
                    good.handle, patch.handle, weight.handle, bad.handle,
                    OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED) == OPENCV_IMGPROC_OK,
                "recovery");
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}



