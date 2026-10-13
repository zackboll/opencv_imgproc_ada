// Revised by explicit review: max(1e-4, 4 Float32 ULPs of rounded oracle).
// Original exact-fixture designation remains in CASE for historical diagnostics.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <cmath>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <stdexcept>

namespace {
bool numerical_failure = false;
double maximum_error = 0, maximum_ulp_error = 0;
double maximum_positive_ulp_error = 0;
std::uint64_t maximum_ulp_distance = 0;
void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
struct Mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *value = nullptr;
    explicit Mat(const cv::Mat &m) {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK, "create");
        require(opencv_core_module_output_mat(handle, &value) == OPENCV_CORE_OK,
                "bridge");
        *value = m;
    }
    ~Mat() { opencv_core_mat_destroy(handle); }
    Mat(const Mat &) = delete;
    Mat &operator=(const Mat &) = delete;
};
std::uint64_t oracle(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m,
                     int y, int x) {
    std::uint64_t sum = 0;
    for (int v = 0; v < t.rows; ++v) for (int u = 0; u < t.cols; ++u) {
        if (!m.at<uchar>(v, u)) continue;
        const std::uint64_t term = std::uint64_t(t.at<uchar>(v, u)) *
            s.at<uchar>(y + v, x + u);
        require(term <= 65025 && sum <= UINT64_MAX - term, "oracle overflow");
        sum += term;
    }
    require(sum <= (UINT64_C(1) << 53), "exact double oracle domain");
    return sum;
}
std::uint32_t bits(float v) {
    std::uint32_t b; std::memcpy(&b, &v, sizeof b); return b;
}
double ulp(float v) {
    return double(std::nextafter(v, INFINITY)) - double(v);
}
double ceiling(float v) { return std::max(1e-4, 4 * ulp(v)); }
std::uint64_t ordered(float v) {
    const auto b = bits(v);
    return b >> 31 ? UINT64_C(0x80000000) - (b & 0x7fffffff) :
        UINT64_C(0x80000000) + b;
}
void run(const std::string &name, const cv::Mat &s, const cv::Mat &t,
         const cv::Mat &m, bool exact = false, bool unique = false) {
    Mat source(s), templ(t), mask(m), output(s);
    const auto sb = s.clone(), tb = t.clone(), mb = m.clone();
    require(opencv_imgproc_match_template_masked(source.handle, templ.handle,
        mask.handle, output.handle, OPENCV_IMGPROC_TEMPLATE_CCORR) ==
        OPENCV_IMGPROC_OK, opencv_imgproc_last_error_message());
    const cv::Mat &r = *output.value;
    require(r.type() == CV_32FC1 && r.rows == s.rows - t.rows + 1 &&
        r.cols == s.cols - t.cols + 1 && !r.isSubmatrix() &&
        r.data != s.data, "owning result layout");
    require(cv::norm(s, sb, cv::NORM_INF) == 0 &&
        cv::norm(t, tb, cv::NORM_INF) == 0 &&
        cv::norm(m, mb, cv::NORM_INF) == 0, "input mutation");
    cv::Mat image, patch, weights, control;
    s.convertTo(image, CV_32F); t.convertTo(patch, CV_32F);
    cv::compare(m, 0, weights, cv::CMP_NE);
    weights.convertTo(weights, CV_32F, 1.0 / 255.0);
    if (CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 10))
        cv::matchTemplate(image, patch, control, cv::TM_CCORR, weights);
    const int active = cv::countNonZero(m);
    std::cout << "CASE " << name << ' ' << s.rows << ' ' << s.cols << ' '
        << t.rows << ' ' << t.cols << ' ' << active << ' ' << r.rows << ' '
        << r.cols << ' ' << exact << ' ' << unique << '\n';
    double best = -INFINITY, second = -INFINITY, ca = 0, cr = 0;
    std::uint64_t obest = 0, osecond = 0;
    double budget = 0;
    int best_index = 0, oracle_index = 0;
    for (int y = 0; y < r.rows; ++y) for (int x = 0; x < r.cols; ++x) {
        const auto sum = oracle(s, t, m, y, x);
        const float expected = static_cast<float>(sum), actual = r.at<float>(y, x);
        const double bound = ceiling(expected);
        const double error = std::abs(double(actual) - expected);
        maximum_error = std::max(maximum_error, error);
        maximum_ulp_error = std::max(maximum_ulp_error, error / ulp(expected));
        if (sum) maximum_positive_ulp_error =
            std::max(maximum_positive_ulp_error, error / ulp(expected));
        const auto aorder = ordered(actual), eorder = ordered(expected);
        maximum_ulp_distance = std::max(maximum_ulp_distance,
            aorder > eorder ? aorder - eorder : eorder - aorder);
        budget = std::max(budget, bound + std::abs(double(expected) - double(sum)));
        require(std::isfinite(actual), "nonfinite correlation");
        if (error > bound) {
            std::cerr << name << " at " << x << ',' << y << " actual "
                << std::setprecision(17) << actual << " oracle " << sum
                << " bound " << bound << '\n';
            numerical_failure = true;
        }
        if (active == 0 && actual != 0.0f) {
            std::cerr << name << " zero bits " << std::hex << bits(actual)
                << std::dec << " value " << actual << '\n';
            require(false, "zero mask residual");
        }
        const int index = y * r.cols + x;
        if (actual > best) { second = best; best = actual; best_index = index; }
        else if (actual > second) second = actual;
        if (sum > obest) { osecond = obest; obest = sum; oracle_index = index; }
        else if (sum > osecond) osecond = sum;
        if (!control.empty()) {
            const double b = control.at<float>(y, x);
            require(std::isfinite(b), "nonfinite native control");
            const double delta = std::abs(actual - b);
            ca = std::max(ca, delta);
            cr = std::max(cr, delta / std::max({std::abs(double(actual)),
                                              std::abs(b), 1e-30}));
            require(delta <= 2 * bound, "masked/unmasked discrepancy");
        }
        std::cout << "SCORE " << std::hex << bits(actual) << std::dec << ' '
            << sum << ' ' << std::hex << bits(expected) << std::dec << ' '
            << (double(expected) == double(sum)) << ' ' << std::setprecision(17)
            << error << ' ' << error / ulp(expected) << ' ' << bound
            << " finite ";
        if (control.empty()) std::cout << "unavailable";
        else std::cout << std::hex << bits(control.at<float>(y, x)) << std::dec;
        std::cout << '\n';
    }
    if (unique) require(best_index == oracle_index, "oracle maximum location");
    if (unique) require(obest > osecond && double(obest - osecond) > 2 * budget,
                        "landmark uncertainty budget");
    std::cout << "MAX " << best_index << ' ' << std::setprecision(17) << best
        << ' ' << (std::isfinite(second) ? best - second : 0) << '\n';
    std::cout << "CONTROL " << ca << ' ' << cr << '\n';
    std::cout << "RANK " << obest << ' ' << osecond << ' ' << best << ' '
        << second << ' ' << obest - osecond << ' ' << best - second << ' '
        << 2 * budget << ' ' << unique << '\n';
}
void guards() {
    using namespace opencv_imgproc_masked_template;
    require(unmasked_fits(1, INT_MAX / 4), "IPP boundary accepted");
    require(!unmasked_fits(1, INT_MAX / 4 + 1), "IPP overflow rejected");
    require(fits(10000, 10000, 31, 29), "large geometry without allocation");
    require(!fits(INT_MAX, 2, 1, 1), "signed area overflow");
    require(!span_fits(2, 1, SIZE_MAX), "span overflow");
    Mat s(cv::Mat(2, 2, CV_8U, cv::Scalar(9)));
    Mat out(cv::Mat(1, 1, CV_8U, cv::Scalar(73)));
    // Borrowed forged headers exercise rejection before snapshot allocation.
    // Real storage remains tiny; never call native computation with these.
    for (const auto &shape : {cv::Size(INT_MAX, 2), cv::Size(30000, 30000)}) {
        cv::Mat fake = s.value->clone();
        fake.rows = shape.height; fake.cols = shape.width;
        fake.step[0] = static_cast<std::size_t>(shape.width);
        Mat header(fake);
        require(opencv_imgproc_match_template_masked(header.handle, header.handle,
            header.handle, out.handle, OPENCV_IMGPROC_TEMPLATE_CCORR) !=
            OPENCV_IMGPROC_OK, "arithmetic rejection before allocation");
        require(out.value->at<uchar>(0, 0) == 73, "arithmetic atomicity");
    }
    for (int selector : {-1, OPENCV_IMGPROC_TEMPLATE_CCOEFF_NORMED}) {
        require(opencv_imgproc_match_template_masked(s.handle, s.handle,
            s.handle, out.handle, selector) != OPENCV_IMGPROC_OK, "selector");
        require(out.value->at<uchar>(0, 0) == 73, "failure atomicity");
    }
    require(opencv_imgproc_match_template_masked(s.handle, s.handle,
        s.handle, s.handle, OPENCV_IMGPROC_TEMPLATE_CCORR) !=
        OPENCV_IMGPROC_OK, "object identity");
    for (const cv::Mat &bad : {cv::Mat(), cv::Mat(2, 2, CV_32F),
            cv::Mat(2, 2, CV_8UC3), cv::Mat(1, 1, CV_8U)}) {
        Mat m(bad);
        require(opencv_imgproc_match_template_masked(s.handle, s.handle,
            m.handle, out.handle, OPENCV_IMGPROC_TEMPLATE_CCORR) !=
            OPENCV_IMGPROC_OK, "invalid representation");
        require(out.value->at<uchar>(0, 0) == 73, "rejection publication");
    }
    run("recovery", *s.value, *s.value, *s.value, true);
}
}
int main() {
    try {
        require(std::string(CV_VERSION) == cv::getVersionString(), "runtime version");
        std::cout << "VERSION " << CV_VERSION << '\n';
        guards();
        for (const auto &size : {cv::Size(1, 1), cv::Size(3, 1), cv::Size(1, 4),
                cv::Size(3, 2), cv::Size(4, 5), cv::Size(31, 29)}) {
            cv::Mat parent(size.height + 6, size.width + 8, CV_8U);
            for (int y = 0; y < parent.rows; ++y)
                for (int x = 0; x < parent.cols; ++x)
                    parent.at<uchar>(y, x) = uchar((y * 17 + x * 29 + 3) % 256);
            const auto s = parent(cv::Rect(1, 1, size.width + 4, size.height + 3));
            const auto t = parent(cv::Rect(3, 2, size.width, size.height));
            for (int mode = 0; mode < 4; ++mode) {
                cv::Mat mp(parent.rows, parent.cols, CV_8U, cv::Scalar(0));
                auto m = mp(cv::Rect(2, 2, size.width, size.height));
                for (int y = 0; y < m.rows; ++y)
                    for (int x = 0; x < m.cols; ++x)
                        m.at<uchar>(y, x) = mode == 0 ? 255 : mode == 1 ?
                            uchar((y + x) % 3 ? 7 : 0) : mode == 2 ? 0 :
                            uchar(y == 0 && x == 0);
                run(std::to_string(size.width) + "x" +
                    std::to_string(size.height) + "-mask" + std::to_string(mode),
                    s, t, m);
            }
        }
        cv::Mat t(2, 3, CV_8U, cv::Scalar(0));
        cv::Mat m(2, 3, CV_8U, cv::Scalar(0));
        t.at<uchar>(0, 0) = 17; t.at<uchar>(0, 2) = 31;
        t.at<uchar>(1, 1) = 53;
        m.at<uchar>(0, 0) = 1; m.at<uchar>(0, 2) = 7;
        m.at<uchar>(1, 1) = 255;
        cv::Mat s(7, 12, CV_8U, cv::Scalar(0));
        t.copyTo(s(cv::Rect(7, 3, 3, 2)));
        s.at<uchar>(0, 1) = 40; // asymmetric distractor
        run("landmark", s, t, m, true, true);
        cv::Mat brighter; s.convertTo(brighter, CV_8U, 2);
        run("brightness", brighter, t, m, true, true);
        t.at<uchar>(0, 1) = 255; s.at<uchar>(3, 8) = 255;
        run("excluded-corruption", s, t, m, true, true);
        for (int value : {0, 255}) {
            run("equal-" + std::to_string(value),
                cv::Mat(3, 4, CV_8U, cv::Scalar(value)),
                cv::Mat(3, 4, CV_8U, cv::Scalar(255)),
                cv::Mat(3, 4, CV_8U, cv::Scalar(1)), true);
            run("black-template-" + std::to_string(value),
                cv::Mat(9, 11, CV_8U, cv::Scalar(value)),
                cv::Mat(3, 4, CV_8U, cv::Scalar(0)),
                cv::Mat(3, 4, CV_8U, cv::Scalar(1)), true);
        }
        cv::Mat high(37, 43, CV_8U, cv::Scalar(255));
        run("high-dft", high, high(cv::Rect(0, 0, 29, 31)),
            cv::Mat(31, 29, CV_8U, cv::Scalar(7)));
        cv::Mat near(1, 401, CV_8U, cv::Scalar(255));
        near.at<uchar>(0, 400) = 254;
        run("near-tie", near, cv::Mat(1, 400, CV_8U, cv::Scalar(255)),
            cv::Mat(1, 400, CV_8U, cv::Scalar(1)), false, true);
        cv::Mat zero(5, 9, CV_8U, cv::Scalar(255));
        zero(cv::Rect(3, 1, 3, 2)).setTo(0);
        for (int mode = 0; mode < 4; ++mode) {
            cv::Mat support(2, 3, CV_8U, cv::Scalar(mode == 0 ? 255 : 0));
            if (mode == 1) { support.at<uchar>(0, 0) = 7;
                             support.at<uchar>(1, 2) = 127; }
            if (mode == 2) support.at<uchar>(1, 1) = 9;
            run("surrounded-zero-" + std::to_string(mode), zero,
                cv::Mat(2, 3, CV_8U, cv::Scalar(255)), support);
        }
        cv::Mat candidates(1, 5, CV_8U, cv::Scalar(0));
        candidates.at<uchar>(0, 0) = 255; candidates.at<uchar>(0, 4) = 255;
        run("multiple-perfect", candidates, cv::Mat(1, 1, CV_8U, cv::Scalar(255)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(127)));
        cv::Mat close(1, 2, CV_8U, cv::Scalar(254));
        close.at<uchar>(0, 0) = 255;
        run("integer-margin-one", close, cv::Mat(1, 1, CV_8U, cv::Scalar(1)),
            cv::Mat(1, 1, CV_8U, cv::Scalar(7)), false, true);
        cv::Mat large(1, 401, CV_8U, cv::Scalar(255));
        large.at<uchar>(0, 0) = 254;
        run("above-2pow24-odd", large, cv::Mat(1, 400, CV_8U, cv::Scalar(255)),
            cv::Mat(1, 400, CV_8U, cv::Scalar(255)), false, true);
        cv::Mat fragile_source(1, 401, CV_8U, cv::Scalar(255));
        fragile_source.at<uchar>(0, 400) = 254;
        cv::Mat fragile_template(1, 400, CV_8U, cv::Scalar(255));
        fragile_template.at<uchar>(0, 399) = 1;
        run("near-tie-sub-ulp", fragile_source, fragile_template,
            cv::Mat(1, 400, CV_8U, cv::Scalar(7)));
        cv::Mat column(7, 1, CV_8U, cv::Scalar(9));
        column.at<uchar>(5, 0) = 255;
        run("one-column", column, cv::Mat(2, 1, CV_8U, cv::Scalar(7)),
            cv::Mat(2, 1, CV_8U, cv::Scalar(127)));
        cv::Mat shared(9, 13, CV_8U);
        for (int y = 0; y < shared.rows; ++y)
            for (int x = 0; x < shared.cols; ++x)
                shared.at<uchar>(y, x) = uchar((y * 43 + x * 11 + 19) % 256);
        run("three-overlapping-regions", shared(cv::Rect(1, 1, 9, 6)),
            shared(cv::Rect(2, 2, 4, 3)), shared(cv::Rect(3, 2, 4, 3)));
        std::cout << "ORACLE_MAX " << std::setprecision(17) << maximum_error
            << ' ' << maximum_ulp_error << ' ' << maximum_positive_ulp_error
            << ' ' << maximum_ulp_distance << '\n';
        return numerical_failure ? 1 : 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n'; return 1;
    }
}