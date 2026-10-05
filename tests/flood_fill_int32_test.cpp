#include "../cpp/flood_fill_int32_fits.hpp"
#include <cassert>
#include <limits>

int main()
{
    using namespace opencv_imgproc_detail;
    static_assert(int64_t{INT32_MAX} - INT32_MIN == 4294967295LL);
    static_assert(int64_t{-1} - INT32_MIN == INT_MAX);
    static_assert(int64_t{0} - INT32_MIN == int64_t{INT_MAX} + 1);
    assert(flood_fill_int32_span_fits(INT32_MIN, -1));
    assert(flood_fill_int32_span_fits(0, INT32_MAX));
    assert(flood_fill_int32_span_fits(INT32_MIN, INT32_MIN));
    assert(flood_fill_int32_span_fits(INT32_MAX, INT32_MAX));
    assert(!flood_fill_int32_span_fits(INT32_MIN, 0));
    assert(!flood_fill_int32_span_fits(-1, INT32_MAX));
    assert(!flood_fill_int32_span_fits(INT32_MIN, INT32_MAX));
    assert(flood_fill_int32_component_fits(INT32_MIN));
    assert(flood_fill_int32_component_fits(INT32_MAX));
    assert(flood_fill_int32_component_fits(-12.75));
    assert(!flood_fill_int32_component_fits(double{INT32_MIN} - 0.25));
    assert(!flood_fill_int32_component_fits(double{INT32_MAX} + 0.25));
    assert(!flood_fill_int32_component_fits(
        std::numeric_limits<double>::quiet_NaN()));
    assert(!flood_fill_int32_component_fits(
        std::numeric_limits<double>::infinity()));
    assert(!flood_fill_int32_component_fits(
        -std::numeric_limits<double>::infinity()));
}