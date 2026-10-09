// Identical deterministic corpus, exercising the complete production shim.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <iomanip>
#include <stdexcept>

namespace {
int native_calls = 0;
opencv_imgproc_squared_box::Layout expected_layout;
bool expected_normalize = false;
const cv::Mat *original = nullptr;
void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
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
int lookup(int p, int n, int border) {
    if (p >= 0 && p < n) return p;
    if (border == 0) return -1;
    if (border == 1 || n == 1) return p < 0 ? 0 : n - 1;
    while (p < 0 || p >= n) {
        if (p < 0) p = -p - (border == 2 ? 1 : 0);
        else p = 2 * n - p - (border == 2 ? 1 : 2);
    }
    return p;
}
int cases = 0;
void exercise(int rows, int cols, int depth, int channels, cv::Size kernel,
              int normalize, int border, bool region, int pattern) {
    cv::Mat backing(rows + 2, cols + 3, CV_MAKETYPE(depth, channels),
                    cv::Scalar::all(99));
    cv::Mat image = region ? backing(cv::Rect(1, 1, cols, rows)) :
                            cv::Mat(rows, cols, backing.type());
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < cols; ++x)
            for (int c = 0; c < channels; ++c) {
                const int i = x * channels + c;
                const int n = y * cols * channels + i;
                if (depth == CV_8U) {
                    image.ptr<uchar>(y)[i] = pattern == 1 ? 0 : pattern == 2 ?
                        255 : static_cast<uchar>((y*41 + x*17 + c*83) % 256);
                } else {
                    float v = float(y * 3 - x * 2 + c) / 4.0f;
                    if (pattern == 1) v = float(n + 1) / 7.0f;
                    if (pattern == 2) v = -float(n + 1) / 13.0f;
                    if (pattern == 3) v = std::ldexp(float(n % 5 + 1), 100);
                    if (pattern == 4) v = n % 3 == 0 ? std::ldexp(1.0f, 40) :
                                                    float(n % 3 == 1 ? 1 : -2);
                    if (pattern == 5) v = y == 0 ? std::ldexp(1.0f, 40) : 1.0f;
                    if (pattern == 6) v = n % 2 ? std::ldexp(1.0f, -120) :
                                                  std::ldexp(1.0f, 120);
                    if (pattern >= 7 && n == 0) v = pattern == 7 ?
                        std::numeric_limits<float>::quiet_NaN() : pattern == 8 ?
                        std::numeric_limits<float>::infinity() :
                        -std::numeric_limits<float>::infinity();
                    if (pattern == 10 && n == cols * channels - 1)
                        v = std::numeric_limits<float>::infinity();
                    image.ptr<float>(y)[i] = v;
                }
            }
    const cv::Mat before = image.clone();
    Mat source(image), output(cv::Mat{});
    original = source.value;
    expected_normalize = normalize != 0;
    require(opencv_imgproc_squared_box::plan(rows, cols, depth, channels,
                kernel.width, kernel.height, normalize, border, expected_layout),
            "fixture layout");
    const int previous_calls = native_calls;
    const int abi_border = border == cv::BORDER_REFLECT_101 ?
        OPENCV_IMGPROC_BORDER_REFLECT_101 : border;
    require(opencv_imgproc_squared_box_filter(source.handle, kernel.width,
                kernel.height, normalize, abi_border, output.handle) ==
            OPENCV_IMGPROC_OK, "production filter");
#ifdef SQUARED_BOX_INTERCEPT
    require(native_calls == previous_calls + 1, "one native squared box call");
#else
    (void)previous_calls;
#endif
    const cv::Mat &result = *output.value;
    require(result.size() == image.size() && result.depth() == CV_64F &&
            result.channels() == channels && result.data != image.data &&
            !result.isSubmatrix(), "fresh owning output metadata");
    for (int y = 0; y < rows; ++y)
        require(std::memcmp(image.ptr(y), before.ptr(y), size_t(cols) *
                            image.elemSize()) == 0, "source preservation");
    int kw = kernel.width, kh = kernel.height;
    if (normalize && border != 0) {
        if (cols == 1) kw = 1;
        if (rows == 1) kh = 1;
    }
    const char category = depth == CV_8U ? (normalize ? 'B' : 'A') :
                          pattern >= 7 ? 'D' : 'C';
    std::cout << cases++ << ' ' << category << ' ' << rows << ' ' << cols << ' '
              << depth << ' ' << channels << ' ' << kernel.width << ' '
              << kernel.height << ' ' << normalize << ' ' << border << ' '
              << region << ' ' << pattern << ' ' << result.rows << ' '
              << result.cols << ' ' << result.depth() << ' ' << result.channels();
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < cols; ++x)
            for (int c = 0; c < channels; ++c) {
                const double actual = result.ptr<double>(y)[x * channels + c];
                // Correctness oracle is intentionally separate from consistency.
                // High-dynamic-range/nonfinite native histories are not exact sums.
                if (depth == CV_8U || pattern <= 2) {
                    long double sum = 0;
                    for (int j = 0; j < kh; ++j)
                        for (int i = 0; i < kw; ++i) {
                            const int sy = lookup(y + j - kh/2, rows, border);
                            const int sx = lookup(x + i - kw/2, cols, border);
                            if (sy < 0 || sx < 0) continue;
                            const long double v = depth == CV_8U ?
                                image.ptr<uchar>(sy)[sx * channels + c] :
                                image.ptr<float>(sy)[sx * channels + c];
                            sum += v * v;
                        }
                    if (normalize) sum /= kw * kh;
                    const double expected = static_cast<double>(sum);
                    const double budget = depth == CV_8U && !normalize ? 0 :
                        64 * std::numeric_limits<double>::epsilon() *
                        std::max(1.0, std::abs(expected));
                    require(std::abs(actual - expected) <= budget, "oracle");
                }
                uint64_t bits;
                std::memcpy(&bits, &actual, sizeof bits);
                std::cout << ' ' << std::hex << std::setw(16) << std::setfill('0')
                          << bits << std::dec;
            }
    std::cout << '\n';
    const cv::Mat published = output.value->clone();
    for (const auto &bad : {cv::Size(0, 1), cv::Size(-1, 2),
                          cv::Size(INT_MAX, INT_MAX)})
        require(opencv_imgproc_squared_box_filter(source.handle, bad.width,
                    bad.height, 0, abi_border, output.handle) !=
                OPENCV_IMGPROC_OK, "invalid dimensions");
    require(opencv_imgproc_squared_box_filter(source.handle, 1, 1, normalize,
                abi_border, source.handle) != OPENCV_IMGPROC_OK, "identity");
    require(opencv_imgproc_squared_box_filter(nullptr, 1, 1, normalize,
                abi_border, output.handle) != OPENCV_IMGPROC_OK, "null");
    require(opencv_imgproc_squared_box_filter(source.handle, 1, 1, normalize,
                abi_border, nullptr) != OPENCV_IMGPROC_OK, "null output");
    require(opencv_imgproc_squared_box_filter(source.handle, 1, 1, 2,
                abi_border, output.handle) != OPENCV_IMGPROC_OK, "mode");
    require(opencv_imgproc_squared_box_filter(source.handle, 1, 1, normalize,
                OPENCV_IMGPROC_BORDER_WRAP, output.handle) !=
            OPENCV_IMGPROC_OK, "Wrap");
    for (int y = 0; y < rows; ++y)
        require(std::memcmp(output.value->ptr(y), published.ptr(y),
                size_t(cols) * channels * 8) == 0, "failure atomicity");
#ifdef SQUARED_BOX_INTERCEPT
    require(native_calls == previous_calls + 1, "invalid requests never native");
#endif
    require(opencv_imgproc_squared_box::plan(rows, cols, depth, channels,
                1, 1, 0, border, expected_layout), "recovery layout");
    expected_normalize = false;
    require(opencv_imgproc_squared_box_filter(source.handle, 1, 1, 0,
                abi_border, output.handle) == OPENCV_IMGPROC_OK, "recovery");
}
}
#ifdef SQUARED_BOX_INTERCEPT
extern "C" void real_squared_box(const cv::_InputArray &, const cv::_OutputArray &,
                                  int, cv::Size, cv::Point, bool, int)
    asm("__real__ZN2cv12sqrBoxFilterERKNS_11_InputArrayERKNS_12_OutputArrayEiNS_5Size_IiEENS_6Point_IiEEbi");
extern "C" void wrap_squared_box(const cv::_InputArray &, const cv::_OutputArray &,
                                  int, cv::Size, cv::Point, bool, int)
    asm("__wrap__ZN2cv12sqrBoxFilterERKNS_11_InputArrayERKNS_12_OutputArrayEiNS_5Size_IiEENS_6Point_IiEEbi");
extern "C" void wrap_squared_box(const cv::_InputArray &input,
                                  const cv::_OutputArray &output, int depth,
                                  cv::Size kernel, cv::Point anchor,
                                  bool normalize, int border) {
    ++native_calls;
    const cv::Mat m = input.getMat();
    const auto &p = expected_layout;
    require(m.rows == p.native_height && m.cols == p.native_width &&
            m.type() == original->type() && m.datastart != original->datastart &&
            m.u != nullptr, "private native geometry and ownership");
    require(kernel == cv::Size(p.kernel_width, p.kernel_height) &&
            anchor == cv::Point(0, 0) && normalize == expected_normalize &&
            depth == CV_64F && border == cv::BORDER_REPLICATE,
            "effective kernel, explicit anchor, native mode");
    cv::Size whole;
    cv::Point offset;
    m.locateROI(whole, offset);
    require(offset == cv::Point(0, 0) &&
            whole == cv::Size(p.parent_width, p.parent_height) &&
            whole.width - m.cols >= kernel.width - 1 &&
            whole.height - m.rows >= kernel.height,
            "zero unsafe border extents and bottom pointer guard");
    real_squared_box(input, output, depth, kernel, anchor, normalize, border);
}
#endif

int main() {
    try {
        std::cout << "squared-box-v1 " << CV_VERSION << '\n';
        for (int rows : {1, 2, 5})
            for (int cols : {1, 3, 6})
                for (int depth : {CV_8U, CV_32F})
                    for (int channels : {1, 3})
                        for (int normalize : {0, 1})
                            for (int border : {0, 1, 2, 4})
                                for (cv::Size kernel : {cv::Size(1, 1), {3, 3},
                                                       {2, 4}, {3, 5}, {9, 8}})
                                    for (bool region : {false, true})
                                        exercise(rows, cols, depth, channels,
                                            kernel, normalize, border, region, 0);
        for (int depth : {CV_8U, CV_32F})
            for (int pattern = 1; pattern <= (depth == CV_8U ? 2 : 10); ++pattern)
                for (int channels : {1, 3})
                    for (int normalize : {0, 1})
                        for (int border : {0, 1, 2, 4})
                            for (cv::Size kernel : {cv::Size(1, 1), {3, 1},
                                                   {1, 3}, {2, 4}, {9, 8}})
                                exercise(2, 3, depth, channels, kernel,
                                         normalize, border, true, pattern);
        for (int normalize : {0, 1})
            for (int border : {0, 1, 2, 4})
                for (int channels : {1, 3})
                    exercise(1, 1, CV_8U, channels, {181, 182}, normalize,
                             border, false, 2);
        exercise(1, 1, CV_8U, 1, {33025, 1}, 0, 1, false, 2);
        for (const cv::Mat &bad : {cv::Mat{}, cv::Mat(2, 2, CV_64FC1),
                                  cv::Mat(2, 2, CV_8UC2)}) {
            Mat source(bad), output(cv::Mat{});
            require(opencv_imgproc_squared_box_filter(source.handle, 1, 1,
                        0, 1, output.handle) != OPENCV_IMGPROC_OK,
                    "raw source representation");
            require(output.value->empty(), "failed result remains empty");
        }
        const int shape[] = {2, 2, 2};
        Mat volume(cv::Mat(3, shape, CV_8UC1)), output(cv::Mat{});
        require(opencv_imgproc_squared_box_filter(volume.handle, 1, 1, 0, 1,
                    output.handle) != OPENCV_IMGPROC_OK, "raw 3-D rejected");
        Mat bytes(cv::Mat(2, 2, CV_8UC1, cv::Scalar::all(255)));
        require(opencv_imgproc_squared_box_filter(bytes.handle, 33026, 1, 0, 1,
                    output.handle) != OPENCV_IMGPROC_OK, "raw signed area");
        require(output.value->empty(), "boundary failure atomicity");
        std::cerr << cases << " production cases passed\n";
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}