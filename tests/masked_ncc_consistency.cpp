// Production-shim masked NCC corpus. Absolute ceiling 1e-4 was fixed before
// cross-version comparison and is not fitted to observations.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <cmath>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
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
// Fixtures are small enough that all UInt8 products sum exactly in uint64_t.
struct Energy { std::uint64_t num, templ, scene; };
Energy energy(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m, int y, int x) {
    Energy result{0, 0, 0};
    for (int v = 0; v < t.rows; ++v) for (int u = 0; u < t.cols; ++u)
        if (m.at<uchar>(v, u)) {
            const std::uint64_t tv = t.at<uchar>(v, u);
            const std::uint64_t iv = s.at<uchar>(y + v, x + u);
            result.num += tv * iv; result.templ += tv * tv; result.scene += iv * iv;
        }
    return result;
}
void run(const std::string &id, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m, bool expect_tie = false);
void guards();
}  // namespace

namespace {
void run(const std::string &id, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m, bool expect_tie) {
    Mat source(s), templ(t), mask(m);
    Mat result(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    const auto sb = s.clone(), tb = t.clone(), mb = m.clone();
    cv::Mat image, patch, weights, native;
    s.convertTo(image, CV_32F);
    t.convertTo(patch, CV_32F);
    cv::compare(m, 0, weights, cv::CMP_NE);
    weights.convertTo(weights, CV_32F, 1.0 / 255.0);
    cv::matchTemplate(image, patch, native, cv::TM_CCORR_NORMED, weights);
    double native_min = INFINITY, native_max = -INFINITY;
    cv::Point native_min_at(-1, -1), native_max_at(-1, -1);
    require(opencv_imgproc_match_template_masked(
        source.handle, templ.handle, mask.handle, result.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) == OPENCV_IMGPROC_OK,
        opencv_imgproc_last_error_message());
    const auto &r = *result.value;
    require(r.type() == CV_32FC1 && r.rows == s.rows - t.rows + 1 &&
        r.cols == s.cols - t.cols + 1 && !r.isSubmatrix(), "result layout");
    require(cv::norm(s, sb, cv::NORM_INF) == 0 &&
        cv::norm(t, tb, cv::NORM_INF) == 0 &&
        cv::norm(m, mb, cv::NORM_INF) == 0, "input mutation");
    const long double template_energy = energy(t, t, m, 0, 0).templ;
    require(template_energy > 0, "fixture template energy");
    std::cout << "CASE " << id << ' ' << s.rows << ' ' << s.cols << ' '
        << t.rows << ' ' << t.cols << ' ' << cv::countNonZero(m) << ' '
        << std::hexfloat << static_cast<double>(template_energy)
        << std::defaultfloat << ' ' << r.rows << ' ' << r.cols << '\n';
    int best_count = 0;
    double best = -1, second = -1;
    cv::Point best_at(-1, -1);
    for (int y = 0; y < r.rows; ++y) for (int x = 0; x < r.cols; ++x) {
        const Energy value = energy(s, t, m, y, x);
        const float score = r.at<float>(y, x);
        const float raw = native.at<float>(y, x);
        std::uint32_t raw_bits = 0, score_bits = 0;
        std::memcpy(&raw_bits, &raw, sizeof(raw_bits));
        std::memcpy(&score_bits, &score, sizeof(score_bits));
        std::cout << "NATIVE " << std::hex << raw_bits << std::dec << ' '
            << (std::isnan(raw) ? "nan" : std::isinf(raw) ? "inf" : "finite")
            << ' ' << value.scene << '\n';
        if (std::isfinite(raw)) {
            if (raw < native_min) { native_min = raw; native_min_at = {x, y}; }
            if (raw > native_max) { native_max = raw; native_max_at = {x, y}; }
        }
        if (value.scene == 0)
            require(score_bits == 0, "zero-window exact positive zero bits");
        else {
            require(score_bits == raw_bits, "positive-energy native bits changed");
            const long double ideal =
                static_cast<long double>(value.num) /
                std::sqrt(static_cast<long double>(value.templ) * value.scene);
            require(std::isfinite(score) &&
                std::abs(static_cast<long double>(score) - ideal) <= 1e-4L,
                "independent widened oracle");
        }
        std::uint32_t bits = 0;
        std::memcpy(&bits, &score, sizeof(bits));
        std::cout << "SCORE " << std::hex << std::setw(8) << std::setfill('0')
            << bits << std::dec << '\n';
        if (!std::isfinite(score)) continue;
        if (score > best + 1e-12) {
            second = best;
            best = score;
            best_at = cv::Point(x, y);
            best_count = 1;
        } else if (std::abs(score - best) <= 1e-12) {
            ++best_count;
        } else {
            second = std::max(second, static_cast<double>(score));
        }
    }
    if (id.find("translated") != std::string::npos)
        require(best_at == cv::Point(2, 1) && best_count == 1, "known maximum");
    if (expect_tie) require(best_count > 1, "expected genuine score tie");
    std::cout << "NATIVE_EXTREMA " << std::hexfloat << native_min << ' '
        << native_max << std::defaultfloat << ' ' << native_min_at.x << ' '
        << native_min_at.y << ' ' << native_max_at.x << ' '
        << native_max_at.y << '\n';
    std::cout << "MAX " << best_at.x << ' ' << best_at.y << ' ' << best_count
        << ' ' << std::hexfloat << best << ' ' << second
        << std::defaultfloat << '\n';
}
}  // namespace

namespace {
void guards() {
    using opencv_imgproc_masked_template::fits;
    require(fits(10000, 10000, 101, 99), "representable large geometry");
    require(!fits(INT_MAX, 2, 1, 1), "signed area");
    require(!fits(1, INT_MAX, 1, 1), "signed byte width");
    Mat a(cv::Mat(2, 2, CV_8U, cv::Scalar(1)));
    Mat out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    for (int selector : {1, 2, 4, 5})
        require(opencv_imgproc_match_template_masked(
            a.handle, a.handle, a.handle, out.handle, selector) ==
            OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "selector");
    require(out.value->at<uchar>(0, 0) == 73, "failed publication");
    Mat zero(cv::Mat(2, 2, CV_8U, cv::Scalar(0)));
    require(opencv_imgproc_match_template_masked(
        a.handle, zero.handle, a.handle, out.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) ==
        OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "zero template");
    require(opencv_imgproc_match_template_masked(
        a.handle, a.handle, zero.handle, out.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) ==
        OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "zero mask");
    require(opencv_imgproc_match_template_masked(
        a.handle, a.handle, a.handle, out.handle, 0) == OPENCV_IMGPROC_OK,
        "sqdiff recovery");
    require(opencv_imgproc_match_template_masked(
        a.handle, a.handle, a.handle, out.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) == OPENCV_IMGPROC_OK, "ncc");
    require(opencv_imgproc_match_template_masked(
        nullptr, a.handle, a.handle, out.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) ==
        OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "null");
    require(opencv_imgproc_match_template_masked(
        a.handle, a.handle, a.handle, a.handle,
        OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED) ==
        OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT, "identity");
}
}  // namespace

int main() {
    try {
        require(cv::getVersionString() == CV_VERSION, "header/runtime mismatch");
        std::cout << "VERSION " << CV_VERSION << '\n';
        guards();
        for (bool sparse : {false, true}) {
            cv::Mat image(480, 640, CV_32F, cv::Scalar(0));
            cv::Mat weights(31, 31, CV_32F, cv::Scalar(sparse ? 0 : 1));
            weights.at<float>(0, 30) = 1;
            weights.at<float>(30, 0) = 1;
            cv::Mat scores(450, 610, CV_32F, cv::Scalar(1));
            const auto start = std::chrono::steady_clock::now();
            for (int repeat = 0; repeat < 3; ++repeat)
                opencv_imgproc_masked_template::normalize_zero_scene(
                    image, weights, scores);
            const double ms = std::chrono::duration<double, std::milli>(
                std::chrono::steady_clock::now() - start).count() / 3;
            require(cv::countNonZero(scores) == 0, "large all-zero classifier");
            std::cout << "SUPPORT_BENCH " << (sparse ? "sparse" : "full")
                << ' ' << ms << " ms\n";
        }
        run("exact", cv::Mat(2, 3, CV_8U, cv::Scalar(40)),
            cv::Mat(2, 3, CV_8U, cv::Scalar(40)),
            cv::Mat(2, 3, CV_8U, cv::Scalar(255)));
        cv::Mat scene(5, 7, CV_8U, cv::Scalar(20));
        cv::Mat patch(2, 3, CV_8U);
        const uchar pattern[] = {9, 40, 200, 17, 80, 3};
        for (int i = 0; i < 6; ++i)
            patch.at<uchar>(i / 3, i % 3) = pattern[i];
        patch.copyTo(scene(cv::Rect(2, 1, 3, 2)));
        cv::Mat full(2, 3, CV_8U, cv::Scalar(1));
        run("translated", scene, patch, full);
        cv::Mat bright = scene.clone();
        bright.convertTo(bright, CV_8U, 2.0);
        cv::Mat bright_patch;
        patch.convertTo(bright_patch, CV_8U, 2.0);
        run("brightness-scaled", bright, bright_patch, full);
        cv::Mat levels(4, 5, CV_8U);
        for (int y = 0; y < 4; ++y) for (int x = 0; x < 5; ++x)
            levels.at<uchar>(y, x) = uchar(30 + 20 * ((x + y) % 3));
        run("brightness-levels", levels, levels(cv::Rect(1, 1, 2, 2)).clone(),
            cv::Mat(2, 2, CV_8U, cv::Scalar(255)));
        cv::Mat visibility(2, 3, CV_8U, cv::Scalar(0));
        visibility.at<uchar>(0, 1) = 1;
        visibility.at<uchar>(1, 0) = 255;
        visibility.at<uchar>(1, 2) = 127;
        cv::Mat corrupted = patch.clone();
        corrupted.at<uchar>(0, 0) ^= 255;
        corrupted.at<uchar>(0, 2) ^= 128;
        run("excluded-template", scene, corrupted, visibility);
        cv::Mat scene_corrupt = scene.clone();
        scene_corrupt.at<uchar>(1, 2) ^= 255;
        run("excluded-scene", scene_corrupt, patch, visibility);
        cv::Mat candidates(1, 7, CV_8U);
        const uchar row[] = {4, 9, 1, 4, 9, 8, 4};
        std::memcpy(candidates.ptr(), row, sizeof(row));
        cv::Mat mark(1, 2, CV_8U);
        mark.at<uchar>(0, 0) = 4;
        mark.at<uchar>(0, 1) = 9;
        run("multiple", candidates, mark, cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        cv::Mat near_scene(1, 4, CV_8U);
        const uchar near_pixels[] = {10, 20, 10, 21};
        std::memcpy(near_scene.ptr(), near_pixels, sizeof(near_pixels));
        cv::Mat near_patch(1, 2, CV_8U);
        near_patch.at<uchar>(0, 0) = 10;
        near_patch.at<uchar>(0, 1) = 20;
        run("near-tie", near_scene, near_patch,
            cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        run("distractor", candidates, mark,
            cv::Mat(1, 2, CV_8U, cv::Scalar(255)));
        run("uniform", cv::Mat(3, 4, CV_8U, cv::Scalar(70)),
            cv::Mat(2, 2, CV_8U, cv::Scalar(15)),
            cv::Mat(2, 2, CV_8U, cv::Scalar(1)));
        cv::Mat sparse(3, 3, CV_8U, cv::Scalar(0));
        sparse.at<uchar>(0, 2) = 1;
        sparse.at<uchar>(2, 0) = 200;
        run("sparse", cv::Mat(5, 5, CV_8U, cv::Scalar(12)),
            cv::Mat(3, 3, CV_8U, cv::Scalar(40)), sparse);
        cv::Mat nonbinary(2, 2, CV_8U);
        nonbinary.at<uchar>(0, 0) = 2;
        nonbinary.at<uchar>(0, 1) = 0;
        nonbinary.at<uchar>(1, 0) = 99;
        nonbinary.at<uchar>(1, 1) = 254;
        run("nonbinary", cv::Mat(3, 3, CV_8U, cv::Scalar(25)),
            cv::Mat(2, 2, CV_8U, cv::Scalar(50)), nonbinary);
        cv::Mat dark(1, 3, CV_8U, cv::Scalar(0));
        dark.at<uchar>(0, 2) = 8;
        run("zero-window", dark, cv::Mat(1, 2, CV_8U, cv::Scalar(6)),
            cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        for (int neighbor : {1, 2, 7, 8, 9, 10, 127, 255}) {
            dark.at<uchar>(0, 2) = uchar(neighbor);
            run("zero-neighbor-" + std::to_string(neighbor), dark,
                cv::Mat(1, 2, CV_8U, cv::Scalar(6)),
                cv::Mat(1, 2, CV_8U, cv::Scalar(1)));
        }
        for (bool sparse_mask : {false, true}) {
            cv::Mat black(4, 6, CV_8U, cv::Scalar(0));
            black.at<uchar>(1, 4) = 9;
            black.at<uchar>(3, 5) = 255;
            cv::Mat support(2, 3, CV_8U, cv::Scalar(sparse_mask ? 0 : 1));
            support.at<uchar>(0, 2) = 1;
            support.at<uchar>(1, 0) = 1;
            run(sparse_mask ? "zero-2d-sparse" : "zero-2d-full", black,
                cv::Mat(2, 3, CV_8U, cv::Scalar(6)), support);
            cv::Mat parent(6, 8, CV_8U, cv::Scalar(255));
            black.copyTo(parent(cv::Rect(1, 1, 6, 4)));
            run(sparse_mask ? "zero-region-sparse" : "zero-region-full",
                parent(cv::Rect(1, 1, 6, 4)),
                cv::Mat(2, 3, CV_8U, cv::Scalar(6)), support);
        }
        // Cross-word shifts, padding, non-reflected asymmetric support.
        for (int width : {63, 64, 65, 127, 129}) {
            cv::Mat black(3, width + 70, CV_8U, cv::Scalar(0));
            black.at<uchar>(1, width + 3) = 19;
            cv::Mat support(2, 67, CV_8U, cv::Scalar(0));
            support.at<uchar>(0, 1) = 1;
            support.at<uchar>(1, 64) = 1;
            support.at<uchar>(1, 66) = 1;
            run("zero-word-" + std::to_string(width), black,
                cv::Mat(2, 67, CV_8U, cv::Scalar(6)), support);
        }
        run("singleton", cv::Mat(2, 2, CV_8U, cv::Scalar(9)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(4)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(1)));
        run("equal-size", cv::Mat(3, 2, CV_8U, cv::Scalar(11)),
            cv::Mat(3, 2, CV_8U, cv::Scalar(19)),
            cv::Mat(3, 2, CV_8U, cv::Scalar(255)));
        for (const auto &size : {cv::Size(2, 3), cv::Size(3, 2),
                cv::Size(4, 5), cv::Size(5, 4), cv::Size(8, 7)}) {
            cv::Mat parent(size.height + 6, size.width + 8, CV_8U);
            for (int y = 0; y < parent.rows; ++y)
                for (int x = 0; x < parent.cols; ++x)
                    parent.at<uchar>(y, x) =
                        uchar((y * 17 + x * 29 + 3) % 251 + 1);
            cv::Mat source = parent(cv::Rect(
                1, 2, size.width + 3, size.height + 2));
            cv::Mat templ = parent(cv::Rect(3, 3, size.width, size.height));
            cv::Mat mask_parent(
                size.height + 2, size.width + 2, CV_8U, cv::Scalar(9));
            cv::Mat region_mask =
                mask_parent(cv::Rect(1, 1, size.width, size.height));
            for (int y = 0; y < region_mask.rows; ++y)
                for (int x = 0; x < region_mask.cols; ++x)
                    if ((x + y) % 4 == 0) region_mask.at<uchar>(y, x) = 0;
            run(std::to_string(size.width) + "x" +
                std::to_string(size.height) + "-regions",
                source, templ, region_mask);
        }
        cv::Mat tied(1, 3, CV_8U, cv::Scalar(5));
        tied.at<uchar>(0, 0) = 9;
        tied.at<uchar>(0, 2) = 9;
        run("one-pixel-tie", tied, cv::Mat(1, 1, CV_8U, cv::Scalar(9)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(1)), true);
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
