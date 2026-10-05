#include "../cpp/blend_linear_layout_fits.hpp"

#include <cassert>
#include <limits>

using opencv_imgproc_detail::blend_linear_layout_fits;

static_assert(blend_linear_layout_fits(INT_MAX, 1));
static_assert(!blend_linear_layout_fits(int64_t{INT_MAX} + 1, 1));
static_assert(blend_linear_layout_fits(INT_MAX / 3, 3));
static_assert(!blend_linear_layout_fits(INT_MAX / 3 + 1, 3));
static_assert(blend_linear_layout_fits(0, 1));
static_assert(!blend_linear_layout_fits(1, 0));
static_assert(!blend_linear_layout_fits(-1, 1));
static_assert(!blend_linear_layout_fits(1, -1));
static_assert(!blend_linear_layout_fits(INT_MAX, INT_MAX));
static_assert(!blend_linear_layout_fits(
    std::numeric_limits<int64_t>::max(), 2));

int main()
{
    for (int64_t channels = 1; channels <= 512; ++channels) {
        const int64_t columns = INT_MAX / channels;
        assert(blend_linear_layout_fits(columns, channels));
        assert(!blend_linear_layout_fits(columns + 1, channels));
    }
}