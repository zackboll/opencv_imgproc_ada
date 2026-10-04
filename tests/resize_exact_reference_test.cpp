// Independent fixture derivation: only integer coefficient/rounding arithmetic.
// OpenCV is used to verify results, never to produce expected values.
#include <opencv2/imgproc.hpp>
#include <array>
#include <cassert>
#include <cstdint>
#include <iostream>

template<class T> void check(const std::array<T, 6>& source, int type, int bits)
{
    const int64_t unit = int64_t{1} << bits;
    const int64_t xweight[] = {0, (unit * 2 + 2) / 5, 0,
                              (unit * 3 + 2) / 5, 0};
    const int xoffset[] = {0, 0, 1, 1, 2};
    cv::Mat input(2, 3, type, const_cast<T*>(source.data())), exact, linear;
    cv::resize(input, exact, cv::Size(5, 3), 0, 0, cv::INTER_LINEAR_EXACT);
    cv::resize(input, linear, cv::Size(5, 3), 0, 0, cv::INTER_LINEAR);
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 5; ++x) {
            const int a = xoffset[x], b = std::min(a + 1, 2);
            const int64_t top = source[a] * (unit - xweight[x]) +
                                source[b] * xweight[x];
            const int64_t bottom = source[3 + a] * (unit - xweight[x]) +
                                   source[3 + b] * xweight[x];
            const int64_t mixed = y == 0 ? top * unit :
                                  y == 2 ? bottom * unit :
                                  (top + bottom) * (unit / 2);
            // floor((mixed + half)/unit^2), including negative values.
            const int64_t adjusted = mixed + unit * unit / 2;
            const int64_t expected = adjusted >= 0 ? adjusted / (unit * unit) :
                -((-adjusted + unit * unit - 1) / (unit * unit));
            assert(exact.at<T>(y, x) == expected);
            std::cout << expected << ',';
            if (linear.at<T>(y, x) != expected)
                std::cout << "[Linear=" << +linear.at<T>(y, x) << "]";
        }
        std::cout << '\n';
    }
}

int main()
{
    check<uint8_t>({3, 71, 199, 22, 117, 241}, CV_8UC1, 8);
    check<uint16_t>({101, 12003, 60001, 903, 33007, 65003}, CV_16UC1, 16);
    check<int16_t>({-301, -71, 199, -22, 117, 1241}, CV_16SC1, 16);
}