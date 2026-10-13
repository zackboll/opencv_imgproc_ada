// Production-shim masked correlation-coefficient corpus.
// Criteria fixed before reading any qualification output:
//   Gate A  |score - oracle| <= 1e-4 + 2^-20 * |Sum(M*T*I)|
//   Gate B  |a - b| <= 1e-4 + 2^-20 * |Sum(M*T*I)|  (compare script)
//   Gate C  raw bits equal to the selected native / composed control
//   Gate D  oracle margin > 2 * budget on designated robust landmarks
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

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

std::uint64_t checked_mul(std::uint64_t a, std::uint64_t b) {
    if (a != 0 && b > UINT64_MAX / a)
        throw std::overflow_error("oracle product exceeds UInt64");
    return a * b;
}

// Exact integer sums. The numerator count*STI - ST*SI is formed from two
// checked UInt64 products and subtracted as sign and magnitude, then divided
// once by count. Fixtures are bounded so neither product can overflow;
// overflow would throw rather than wrap.
struct Sums {
    std::uint64_t count = 0, st = 0, si = 0, sti = 0;
    long double coefficient() const {
        const std::uint64_t left = checked_mul(count, sti);
        const std::uint64_t right = checked_mul(st, si);
        const long double magnitude =
            static_cast<long double>(left >= right ? left - right
                                                   : right - left);
        return (left >= right ? magnitude : -magnitude) /
               static_cast<long double>(count);
    }
};

Sums sums(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m, int y, int x) {
    Sums r;
    for (int v = 0; v < t.rows; ++v)
        for (int u = 0; u < t.cols; ++u) {
            if (m.at<uchar>(v, u) == 0)
                continue;
            const std::uint64_t tv = t.at<uchar>(v, u);
            const std::uint64_t iv = s.at<uchar>(y + v, x + u);
            ++r.count;
            r.st += tv;
            r.si += iv;
            r.sti += tv * iv;
        }
    return r;
}

std::uint32_t bits(float value) {
    std::uint32_t b = 0;
    std::memcpy(&b, &value, 4);
    return b;
}

const char *branch() {
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
    return "native";
#else
    return "compatibility";
#endif
}

// Independent control. 4.10/5.0: direct native masked TM_CCOEFF. 4.1: the
// documented composition rebuilt from public operations only.
cv::Mat control(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m) {
    cv::Mat image, patch, weights, result;
    s.convertTo(image, CV_32F);
    t.convertTo(patch, CV_32F);
    cv::compare(m, 0, weights, cv::CMP_NE);
    weights.convertTo(weights, CV_32F, 1.0 / 255.0);
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
    cv::matchTemplate(image, patch, result, cv::TM_CCOEFF, weights);
#else
    const double n = cv::sum(weights)[0];
    const double mean = cv::sum(weights.mul(patch))[0] / n;
    cv::Mat centered = weights.mul(weights.mul(patch - mean));
    cv::Mat a, b, scaled;
    cv::matchTemplate(image, centered, a, cv::TM_CCORR);
    cv::matchTemplate(image, weights, b, cv::TM_CCORR);
    cv::multiply(b, cv::Scalar::all(cv::sum(centered)[0] / n), scaled);
    cv::subtract(a, scaled, result);
#endif
    return result;
}

int failures = 0;

void run(const std::string &id, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m, bool robust = false) {
    Mat source(s), templ(t), mask(m);
    Mat result(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    const cv::Mat sb = s.clone(), tb = t.clone(), mb = m.clone();
    require(opencv_imgproc_match_template_masked(
                source.handle, templ.handle, mask.handle, result.handle,
                OPENCV_IMGPROC_TEMPLATE_CCOEFF) == OPENCV_IMGPROC_OK,
            opencv_imgproc_last_error_message());
    const cv::Mat &r = *result.value;
    require(r.type() == CV_32FC1 && r.rows == s.rows - t.rows + 1 &&
                r.cols == s.cols - t.cols + 1 && !r.isSubmatrix(),
            "result layout");
    require(cv::norm(s, sb, cv::NORM_INF) == 0 &&
                cv::norm(t, tb, cv::NORM_INF) == 0 &&
                cv::norm(m, mb, cv::NORM_INF) == 0,
            "input mutation");
    const cv::Mat ctl = control(s, t, m);
    require(ctl.size() == r.size(), "control size");
    std::printf("CASE %s %s %d %d\n", id.c_str(), branch(), r.rows, r.cols);
    long double best = -1e300L, second = -1e300L;
    int bx = 0, by = 0, ties = 0, control_mismatch = 0;
    double worst_abs = 0;
    for (int y = 0; y < r.rows; ++y)
        for (int x = 0; x < r.cols; ++x) {
            const Sums q = sums(s, t, m, y, x);
            const long double o = q.coefficient();
            const float score = r.at<float>(y, x);
            require(std::isfinite(score), "nonfinite score");
            const double scale = static_cast<double>(q.sti);
            const double err = std::fabs(double(score) - double(o));
            worst_abs = std::fmax(worst_abs, err);
            if (err > 1e-4 + std::ldexp(1.0, -20) * std::fabs(scale)) {
                ++failures;
                std::fprintf(stderr, "GATE_A %s (%d,%d) %g vs %Lg\n",
                             id.c_str(), y, x, double(score), o);
            }
            if (bits(score) != bits(ctl.at<float>(y, x)))
                ++control_mismatch;
            std::printf("SCORE %08x %.1f %.17Lg %08x %llu %llu %llu %llu\n",
                        bits(score), scale, o, bits(ctl.at<float>(y, x)),
                        (unsigned long long)q.count,
                        (unsigned long long)q.st, (unsigned long long)q.si,
                        (unsigned long long)q.sti);
            if (o > best) {
                second = best;
                best = o;
                bx = x;
                by = y;
                ties = 1;
            } else if (o == best) {
                ++ties;
                second = o;
            } else if (o > second) {
                second = o;
            }
        }
    cv::Point native_max;
    cv::minMaxLoc(r, nullptr, nullptr, nullptr, &native_max);
    const long double margin = second < -1e299L ? 0.0L : best - second;
    std::printf("RANK %d %d %d %d %d %.17Lg %.17Lg %.17Lg\n", bx, by,
                native_max.x, native_max.y, ties, best, second, margin);
    std::printf("CONTROL %d %.9g\n", control_mismatch, worst_abs);
    if (control_mismatch != 0) {
        ++failures;
        std::fprintf(stderr, "GATE_C %s %d mismatches\n", id.c_str(),
                     control_mismatch);
    }
    if (robust) {
        const long double budget =
            1e-4L + std::ldexp(1.0L, -20) * std::fabs(best) * 2;
        if (!(ties == 1 && margin > 2 * budget && native_max.x == bx &&
              native_max.y == by)) {
            ++failures;
            std::fprintf(stderr, "GATE_D %s margin %Lg budget %Lg\n",
                         id.c_str(), margin, budget);
        }
    }
}

cv::Mat texture(int rows, int cols, int salt = 0) {
    cv::Mat image(rows, cols, CV_8U);
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < cols; ++x)
            image.at<uchar>(y, x) = static_cast<uchar>(
                (y * 37 + x * 91 + y * x * 13 + salt) % 251);
    return image;
}

cv::Mat sparse_mask(int rows, int cols) {
    cv::Mat mask(rows, cols, CV_8U, cv::Scalar(0));
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < cols; ++x)
            if ((y * 3 + x * 5) % 4 != 0)
                mask.at<uchar>(y, x) = static_cast<uchar>(1 + (y + x) % 255);
    return mask;
}

void expect_rejected(const char *label, const cv::Mat &s, const cv::Mat &t,
                     const cv::Mat &m) {
    Mat source(s), templ(t), mask(m);
    Mat out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    require(opencv_imgproc_match_template_masked(
                source.handle, templ.handle, mask.handle, out.handle,
                OPENCV_IMGPROC_TEMPLATE_CCOEFF) ==
                OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            label);
    require(out.value->at<uchar>(0, 0) == 73, "rejection leaves destination");
}
}  // namespace

int main() {
    try {
        std::printf("VERSION %s %s\n", CV_VERSION, branch());
        const cv::Mat scene = texture(40, 56);
        const cv::Mat patch = scene(cv::Rect(21, 13, 9, 7)).clone();
        const cv::Mat full(7, 9, CV_8U, cv::Scalar(1));
        const cv::Mat sparse = sparse_mask(7, 9);
        run("landmark-full", scene, patch, full, true);
        run("landmark-sparse", scene, patch, sparse, true);
        cv::Mat nonbinary(7, 9, CV_8U, cv::Scalar(0));
        const int bytes[] = {1, 7, 127, 255};
        for (int i = 0; i < 28; ++i)
            nonbinary.at<uchar>(i % 7, (i * 2) % 9) = (uchar)bytes[i % 4];
        run("nonbinary-mask", scene, patch, nonbinary);
        run("scene-offset", scene + 4, patch, sparse);
        run("template-offset", scene, patch + 4, sparse);
        cv::Mat half;
        scene.convertTo(half, CV_8U, 0.5);
        run("positive-scale", half, patch, sparse);
        run("inverted", 255 - scene, patch, full);
        cv::Mat high = scene.clone();
        high.setTo(251, scene > 200);
        run("high-values", high, 255 - patch / 8, sparse);
        cv::Mat corrupt_t = patch.clone(), corrupt_s = scene.clone();
        corrupt_t.setTo(255, sparse == 0);
        run("corrupt-template", scene, corrupt_t, sparse);
        run("corrupt-scene", corrupt_s, patch, sparse);
        run("black-template", scene, cv::Mat(7, 9, CV_8U, cv::Scalar(0)), full);
        run("black-scene", cv::Mat(40, 56, CV_8U, cv::Scalar(0)), patch, full);
        run("constant-template", scene, cv::Mat(7, 9, CV_8U, cv::Scalar(100)),
            full);
        run("constant-scene", cv::Mat(40, 56, CV_8U, cv::Scalar(90)), patch,
            full);
        cv::Mat one(7, 9, CV_8U, cv::Scalar(0));
        one.at<uchar>(3, 4) = 255;
        run("one-pixel", scene, patch, one);
        run("one-by-one", scene, cv::Mat(1, 1, CV_8U, cv::Scalar(200)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(9)));
        run("template-equals-source", patch, patch, sparse);
        run("one-row", texture(1, 33), texture(1, 8, 5),
            cv::Mat(1, 8, CV_8U, cv::Scalar(1)));
        run("one-column", texture(33, 1), texture(8, 1, 5),
            cv::Mat(8, 1, CV_8U, cv::Scalar(3)));
        run("odd-even", texture(21, 20), texture(5, 4, 9), sparse_mask(5, 4));
        cv::Mat ties(1, 6, CV_8U, cv::Scalar(10));
        ties.at<uchar>(0, 1) = 90;
        ties.at<uchar>(0, 4) = 90;
        cv::Mat tie_t(1, 2, CV_8U, cv::Scalar(10));
        tie_t.at<uchar>(0, 1) = 90;
        run("exact-ties", ties, tie_t, cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        cv::Mat near = texture(1, 12, 3);
        near.at<uchar>(0, 3) = 200;
        near.at<uchar>(0, 8) = 201;
        cv::Mat near_t(1, 2, CV_8U, cv::Scalar(100));
        near_t.at<uchar>(0, 1) = 200;
        run("near-tie", near, near_t, cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        const cv::Mat large = texture(150, 200);
        run("dft-large", large, large(cv::Rect(60, 40, 31, 23)).clone(),
            sparse_mask(23, 31), true);
        const cv::Mat parent = texture(30, 40);
        const cv::Mat region = parent(cv::Rect(2, 3, 30, 20));
        run("region-source", region, region(cv::Rect(5, 4, 6, 5)).clone(),
            cv::Mat(5, 6, CV_8U, cv::Scalar(1)));

        expect_rejected("all-zero rejected", scene, patch,
                        cv::Mat(7, 9, CV_8U, cv::Scalar(0)));
        Mat a(cv::Mat(2, 2, CV_8U, cv::Scalar(1)));
        Mat out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
        for (int selector : {-1, OPENCV_IMGPROC_TEMPLATE_CCOEFF_NORMED}) {
            require(opencv_imgproc_match_template_masked(
                        a.handle, a.handle, a.handle, out.handle, selector) ==
                        OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                    "selector rejected");
            require(out.value->at<uchar>(0, 0) == 73, "selector atomicity");
        }
        require(opencv_imgproc_match_template_masked(
                    a.handle, a.handle, a.handle, out.handle,
                    OPENCV_IMGPROC_TEMPLATE_CCOEFF) == OPENCV_IMGPROC_OK,
                "recovery");
        using opencv_imgproc_masked_template::fits;
        using opencv_imgproc_masked_template::span_fits;
        using opencv_imgproc_masked_template::unmasked_fits;
        require(span_fits(30000, 20000, 20000), "30000x20000 stride");
        require(fits(30000, 20000, 30000, 20000), "shared geometry");
        require(!unmasked_fits(30000, 20000), "IPP area boundary preserved");
        cv::Mat forged(2, 2, CV_8U, cv::Scalar(4));
        forged.rows = 30000;
        forged.cols = 20000;
        forged.step[0] = 20000;
        Mat forged_in(forged);
        Mat forged_out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10)
        // Native path: the legacy IPP area guard is not applied. The same
        // object as Source and Destination is rejected by identity before
        // any native work or forged-pointer read.
        require(opencv_imgproc_match_template_masked(
                    forged_in.handle, forged_in.handle, forged_in.handle,
                    forged_in.handle, OPENCV_IMGPROC_TEMPLATE_CCOEFF) ==
                    OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "native forged header rejected");
        require(std::string(opencv_imgproc_last_error_message()).find(
                    "aliases an input") != std::string::npos,
                "native rejection is object identity");
#else
        require(opencv_imgproc_match_template_masked(
                    forged_in.handle, forged_in.handle, forged_in.handle,
                    forged_out.handle, OPENCV_IMGPROC_TEMPLATE_CCOEFF) ==
                    OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "legacy forged header rejected");
        require(std::string(opencv_imgproc_last_error_message()).find(
                    "IPP area") != std::string::npos,
                "legacy rejection names the IPP area guard");
#endif
        require(forged_out.value->at<uchar>(0, 0) == 73,
                "forged rejection leaves destination unchanged");
        std::printf("FAILURES %d\n", failures);
        return failures == 0 ? 0 : 1;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}

