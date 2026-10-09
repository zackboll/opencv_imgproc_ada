// Research only. Reuse the preserved adapter construction, not its campaign.
#define main preserved_adapter_campaign
#include "squared_box_adapter.cpp"
#undef main
#include <limits>

namespace {
struct Totals {
    int cases = 0;
    int integral_mismatches = 0;
    int box_mismatches = 0;
};

bool near(long double a, long double b)
{
    if (std::isnan(a) || std::isnan(b))
        return std::isnan(a) && std::isnan(b);
    if (std::isinf(a) || std::isinf(b)) return a == b;
    return std::abs(a - b) <= 1e-12L * std::max(1.0L, std::abs(b));
}

void compare(const cv::Mat& source, int kw, int kh, int normalize, int border,
             Totals& totals, const char* label = nullptr)
{
    using namespace opencv_imgproc_squared_box;
    Layout layout;
    assert(plan(source.rows, source.cols, source.depth(), source.channels(),
                kw, kh, normalize, border, layout));
    const int ax = layout.kernel_width / 2, ay = layout.kernel_height / 2;
    cv::Mat parent(layout.parent_height, layout.parent_width, source.type());
    const auto bytes = source.elemSize();
    for (int y = 0; y < parent.rows; ++y)
        for (int x = 0; x < parent.cols; ++x) {
            int sy = border_index(y - ay, source.rows, border);
            int sx = border_index(x - ax, source.cols, border);
            uchar* p = parent.ptr(y) + static_cast<std::size_t>(x) * bytes;
            if (sy < 0 || sx < 0) std::memset(p, 0, bytes);
            else std::memcpy(p, source.ptr(sy) +
                             static_cast<std::size_t>(sx) * bytes, bytes);
        }
    cv::Mat box;
    cv::sqrBoxFilter(parent(cv::Rect(0, 0, layout.native_width,
                                    layout.native_height)), box, CV_64F,
                    cv::Size(layout.kernel_width, layout.kernel_height),
                    cv::Point(0, 0), normalize != 0, cv::BORDER_REPLICATE);
    cv::Mat sum, square;
    cv::integral(parent, sum, square, CV_64F, CV_64F);
    const int cn = source.channels();
    for (int y = 0; y < source.rows; ++y)
        for (int x = 0; x < source.cols; ++x)
            for (int c = 0; c < cn; ++c) {
                const int right = x + layout.kernel_width;
                const int bottom = y + layout.kernel_height;
                // Widen BEFORE the four-corner arithmetic.
                long double value = static_cast<long double>(
                    square.ptr<double>(bottom)[right * cn + c]) -
                    static_cast<long double>(square.ptr<double>(y)[right * cn + c]) -
                    static_cast<long double>(square.ptr<double>(bottom)[x * cn + c]) +
                    static_cast<long double>(square.ptr<double>(y)[x * cn + c]);
                long double oracle = 0;
                for (int j = 0; j < layout.kernel_height; ++j)
                    for (int i = 0; i < layout.kernel_width; ++i) {
                        const int sy = lookup(y + j - ay, source.rows, border);
                        const int sx = lookup(x + i - ax, source.cols, border);
                        if (sy >= 0 && sx >= 0) {
                            const long double v = sample(source, sy, sx, c);
                            oracle += v * v;
                        }
                    }
                if (normalize) {
                    value /= layout.kernel_width * layout.kernel_height;
                    oracle /= layout.kernel_width * layout.kernel_height;
                }
                const double native = box.ptr<double>(y)[x * cn + c];
                totals.integral_mismatches += !near(value, oracle);
                totals.box_mismatches += !near(native, oracle);
                if (label)
                    std::cout << label << " x=" << x << " y=" << y
                              << " c=" << c << " oracle=" << oracle
                              << " box=" << native << " integral=" << value
                              << '\n';
            }
    ++totals.cases;
}
} // namespace

int main()
{
    Totals ordinary;
    for (int depth : {CV_8U, CV_32F})
        for (int channels : {1, 3})
            for (cv::Size geometry : {cv::Size(1, 1), cv::Size(5, 1),
                                     cv::Size(1, 5), cv::Size(4, 3)}) {
                cv::Mat backing(geometry.height + 2, geometry.width + 3,
                                CV_MAKETYPE(depth, channels), cv::Scalar::all(99));
                cv::Mat source = backing(cv::Rect(1, 1, geometry.width,
                                                 geometry.height));
                for (int y = 0; y < source.rows; ++y)
                    for (int x = 0; x < source.cols * channels; ++x)
                        if (depth == CV_8U)
                            source.ptr<uchar>(y)[x] =
                                static_cast<uchar>((x * 19 + y * 31) % 256);
                        else source.ptr<float>(y)[x] = (x - y * 3) * 0.25F;
                for (int mode : {0, 1})
                    for (int border : {0, 1, 2, 4})
                        for (cv::Size kernel : {cv::Size(1, 1), cv::Size(3, 3),
                             cv::Size(2, 4), cv::Size(7, 8)})
                            compare(source, kernel.width, kernel.height,
                                    mode, border, ordinary);
            }
    assert(ordinary.integral_mismatches == 0 && ordinary.box_mismatches == 0);
    std::cout << "Ordinary comparison cases=" << ordinary.cases << '\n';

    Totals adversarial;
    for (float first : {std::ldexp(1.0F, 40),
                        std::numeric_limits<float>::max(),
                        std::numeric_limits<float>::quiet_NaN(),
                        std::numeric_limits<float>::infinity(),
                        -std::numeric_limits<float>::infinity()}) {
        cv::Mat source(1, 3, CV_32FC1);
        source.ptr<float>()[0] = first;
        source.ptr<float>()[1] = 1;
        source.ptr<float>()[2] = -2;
        compare(source, 1, 1, 0, 0, adversarial, "adversarial");
    }
    // Vertical cancellation: the upper row is outside the bottom-row window.
    cv::Mat vertical(2, 3, CV_32FC1, cv::Scalar::all(1));
    for (int x = 0; x < 3; ++x) vertical.ptr<float>(0)[x] = std::ldexp(1.0F, 40);
    compare(vertical, 3, 1, 0, 0, adversarial, "vertical-prefix");
    for (float special : {std::numeric_limits<float>::quiet_NaN(),
                          std::numeric_limits<float>::infinity(),
                          -std::numeric_limits<float>::infinity()}) {
        for (int x = 0; x < 3; ++x) vertical.ptr<float>(0)[x] = special;
        compare(vertical, 3, 1, 1, 0, adversarial, "vertical-nonfinite");
    }
    assert(adversarial.integral_mismatches > 0);
    std::cout << "Adversarial cases=" << adversarial.cases
              << " integral/oracle mismatches=" << adversarial.integral_mismatches
              << " box/oracle mismatches=" << adversarial.box_mismatches
              << " OpenCV=" << CV_VERSION << '\n';
}