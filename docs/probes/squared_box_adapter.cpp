// Research only: this does not exercise or qualify a production shim.
#include "../../cpp/squared_box_layout_fits.hpp"
#include <opencv2/imgproc.hpp>
#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>

namespace {
// Independent, iterative oracle border rule.
int lookup(int p, int n, int border)
{
    if (p >= 0 && p < n) return p;
    if (border == 0) return -1;
    if (border == 1 || n == 1) return p < 0 ? 0 : n - 1;
    while (p < 0 || p >= n) {
        if (p < 0) p = -p - (border == 2 ? 1 : 0);
        else p = 2 * n - p - (border == 2 ? 1 : 2);
    }
    return p;
}

double sample(const cv::Mat& source, int y, int x, int c)
{
    const int i = x * source.channels() + c;
    return source.depth() == CV_8U ? source.ptr<uchar>(y)[i]
                                  : source.ptr<float>(y)[i];
}

void check(int rows, int columns, int depth, int channels,
           int kw, int kh, int normalize, int border, bool region)
{
    using namespace opencv_imgproc_squared_box;
    cv::Mat backing(rows + 2, columns + 3, CV_MAKETYPE(depth, channels));
    cv::Mat source = region ? backing(cv::Rect(1, 1, columns, rows))
                            : cv::Mat(rows, columns, backing.type());
    backing.setTo(cv::Scalar::all(99));
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < columns; ++x)
            for (int c = 0; c < channels; ++c) {
                const int i = x * channels + c;
                if (depth == CV_8U)
                    source.ptr<uchar>(y)[i] =
                        static_cast<uchar>((y * 41 + x * 17 + c * 83) % 256);
                else source.ptr<float>(y)[i] =
                    static_cast<float>(y * 3 - x * 2 + c) / 4.0F;
            }
    Layout layout;
    assert(plan(rows, columns, depth, channels, kw, kh, normalize, border,
                layout));
    const int ax = layout.kernel_width / 2;
    const int ay = layout.kernel_height / 2;
    cv::Mat parent(layout.parent_height, layout.parent_width, source.type());
    const std::size_t bytes = source.elemSize();
    for (int y = 0; y < parent.rows; ++y)
        for (int x = 0; x < parent.cols; ++x) {
            const int sy = border_index(y - ay, rows, border);
            const int sx = border_index(x - ax, columns, border);
            uchar* target = parent.ptr(y) + static_cast<std::size_t>(x) * bytes;
            if (sy < 0 || sx < 0) std::memset(target, 0, bytes);
            else std::memcpy(target, source.ptr(sy) +
                             static_cast<std::size_t>(sx) * bytes, bytes);
        }
    cv::Mat input = parent(cv::Rect(0, 0, layout.native_width,
                                    layout.native_height));
    cv::Size whole;
    cv::Point offset;
    input.locateROI(whole, offset);
    assert(offset == cv::Point(0, 0));
    assert(whole == parent.size());
    assert(whole.width - input.cols >= layout.kernel_width - 1);
    assert(whole.height - input.rows >= layout.kernel_height);
    cv::Mat result;
    cv::sqrBoxFilter(input, result, CV_64F,
                    cv::Size(layout.kernel_width, layout.kernel_height),
                    cv::Point(0, 0), normalize != 0, cv::BORDER_REPLICATE);
    for (int y = 0; y < rows; ++y)
        for (int x = 0; x < columns; ++x)
            for (int c = 0; c < channels; ++c) {
                long double sum = 0;
                for (int j = 0; j < layout.kernel_height; ++j)
                    for (int i = 0; i < layout.kernel_width; ++i) {
                        const int sy = lookup(y + j - ay, rows, border);
                        const int sx = lookup(x + i - ax, columns, border);
                        if (sy >= 0 && sx >= 0) {
                            const long double value = sample(source, sy, sx, c);
                            sum += value * value;
                        }
                    }
                if (normalize)
                    sum /= layout.kernel_width * layout.kernel_height;
                const double expected = static_cast<double>(sum);
                const double actual = result.ptr<double>(y)[x * channels + c];
                assert(std::abs(actual - expected) <=
                       1e-12 * std::max(1.0, std::abs(expected)));
            }
}
} // namespace

int main()
{
    int count = 0;
    for (int rows : {1, 2, 5})
        for (int columns : {1, 3, 6})
            for (int depth : {CV_8U, CV_32F})
                for (int channels : {1, 3})
                    for (int normalize : {0, 1})
                        for (int border : {0, 1, 2, 4})
                            for (cv::Size kernel : {cv::Size(1, 1),
                                 cv::Size(3, 3), cv::Size(2, 4),
                                 cv::Size(3, 5), cv::Size(9, 8)})
                                for (bool region : {false, true}) {
                                    check(rows, columns, depth, channels,
                                          kernel.width, kernel.height,
                                          normalize, border, region);
                                    ++count;
                                }
    std::cout << count << " research numerical adapter cases passed; OpenCV "
              << CV_VERSION << '\n';
    return 0;
}