#include "../cpp/resize_exact_layout_fits.hpp"

using opencv_imgproc_detail::resize_exact_layout_fits;
constexpr uint64_t imax = INT_MAX;

static_assert(resize_exact_layout_fits(5, 3, 3, 2, 1, 1, 2, 3));
static_assert(resize_exact_layout_fits(5, 3, 3, 2, 6, 2, 4, 48));
static_assert(!resize_exact_layout_fits(0, 3, 3, 2, 1, 1, 2, 3));
static_assert(!resize_exact_layout_fits(1, 1, 1, 1, 1, 1, 2, 1, 0));
static_assert(resize_exact_layout_fits(imax / 2, 1, 1, 1, 1, 1, 2, 1));
static_assert(!resize_exact_layout_fits(imax / 2 + 1, 1, 1, 1, 1, 1, 2, 1));
static_assert(resize_exact_layout_fits(imax / 12, 1, 1, 1, 6, 1, 2, 6));
static_assert(!resize_exact_layout_fits(imax / 12 + 1, 1, 1, 1, 6, 1, 2, 6));
static_assert(resize_exact_layout_fits(1, imax / 2, 1, 1, 1, 1, 2, 1));
static_assert(!resize_exact_layout_fits(1, imax / 2 + 1, 1, 1, 1, 1, 2, 1));
static_assert(resize_exact_layout_fits(46340, 46340, 1, 1, 1, 1, 2, 1));
static_assert(!resize_exact_layout_fits(46341, 46341, 1, 1, 1, 1, 2, 1));
static_assert(!resize_exact_layout_fits(1, 1, imax / 3 + 1, 1, 3, 1, 2, imax));
// Artificial address limit isolates allocation boundaries without allocation.
static_assert(resize_exact_layout_fits(5, 3, 3, 2, 1, 1, 2, 3, 64));
static_assert(!resize_exact_layout_fits(5, 3, 3, 2, 1, 1, 2, 3, 63));
static_assert(!resize_exact_layout_fits(5, 3, 3, 2, 6, 1, 2, 18, 119));
static_assert(!resize_exact_layout_fits(5, 3, 3, 2, 1, 1, 2, 62, 64));
// Exact path retains wide size_t steps; only the 2x Area path narrows them.
static_assert(resize_exact_layout_fits(3, 3, 2, 2, 1, 1, 2, imax + 1));
static_assert(!resize_exact_layout_fits(1, 1, 2, 2, 1, 1, 2, imax + 1));
static_assert(resize_exact_layout_fits(1, 1, 2, 2, 2, 1, 2, imax + 1));

int main() {}