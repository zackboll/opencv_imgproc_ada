#include "../cpp/colormap_layout_fits.hpp"
#include <cassert>
#include <cstddef>
#include <limits>

int main()
{
    using namespace opencv_imgproc_detail;
    assert(colormap_layout_fits(1, INT_MAX / 3));
    assert(!colormap_layout_fits(1, INT_MAX / 3 + 1));
    assert(colormap_layout_fits(INT_MAX / 3, 1));
    assert(!colormap_layout_fits(INT_MAX / 3 + 1, 1));
    assert(!colormap_layout_fits(0, 1));
    assert(!colormap_layout_fits(1, 0));
    assert(!colormap_layout_fits(UINT64_MAX, UINT64_MAX));
    assert(colormap_span_fits(256, 3, 9, 2298));
    assert(!colormap_span_fits(256, 3, 9, 2297));
    assert(!colormap_span_fits(256, 3, UINT64_MAX, UINT64_MAX));
    assert(colormap_span_fits(1, 3, UINT64_MAX, 3));
    assert(!colormap_span_fits(2, 3, 2, 100));
    assert(colormap_span_fits(2, 3, uint64_t{INT_MAX} + 1, UINT64_MAX));
    constexpr uint64_t p = std::numeric_limits<std::ptrdiff_t>::max();
    assert(colormap_span_fits(2, 3, p - 3, p));
    assert(!colormap_span_fits(2, 3, p - 2, p));
}