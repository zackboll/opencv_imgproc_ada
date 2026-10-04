#include "../cpp/morphology_expansion_fits.hpp"
#include <cassert>
#include <cstdint>
#include <limits>

int main()
{
    using opencv_imgproc_detail::morphology_expansion_fits;
    const auto max = std::numeric_limits<std::int32_t>::max();
    assert(morphology_expansion_fits(1, 1, 1, 0, 0, max, true));
    assert(morphology_expansion_fits(3, 1, 1, 1, 0, 1073741823, true));
    assert(!morphology_expansion_fits(3, 1, 1, 1, 0, 1073741824, true));
    assert(!morphology_expansion_fits(1, 3, 1, 0, 1, max, true));
    assert(!morphology_expansion_fits(2, 1, 1, 1, 0, max, true));
    assert(!morphology_expansion_fits(2, 1, 3, 0, 0, max / 2, true));
    // A full-area mixed +/-1 ternary kernel is sparse in BOTH native legs.
    // Do not allocate huge images or execute INT_MAX sparse iterations.
    assert(morphology_expansion_fits(3, 3, 1, 1, 1, max, false));
    assert(morphology_expansion_fits(2, 3, 1, 1, 2, max, false));
    assert(!morphology_expansion_fits(3, 3, 1, 1, 1, max, true));
}