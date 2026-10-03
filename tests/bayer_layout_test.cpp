#include "../cpp/bayer_layout_fits.hpp"

using opencv_imgproc_detail::bayer_layout_fits;
using opencv_imgproc_detail::bayer_source_span_fits;
using opencv_imgproc_detail::bayer_vng_layout_fits;
constexpr uint64_t imax = INT_MAX;
constexpr uint64_t wide_address = INT64_MAX;

static_assert(bayer_layout_fits(3, 3, 1, 2, false, false));
static_assert(bayer_layout_fits(1, 1, 4, 1, false, false));
static_assert(bayer_layout_fits(2, 2, 4, 2, false, false));
static_assert(!bayer_layout_fits(3, 1, 1, 1, false, false));
static_assert(bayer_layout_fits(3, 1, 3, 1, false, true));
static_assert(bayer_layout_fits(1, imax / 4, 4, 1, false, false,
                                wide_address));
static_assert(!bayer_layout_fits(1, imax / 4 + 1, 4, 1, false, false,
                                 wide_address));
// Largest signed index, not an arbitrary whole-image size limit.
static_assert(bayer_layout_fits(2, (imax + 1) / 2, 1, 1, false, false,
                                wide_address));
static_assert(!bayer_layout_fits(2, (imax + 1) / 2 + 1, 1, 1, false, false,
                                 wide_address));
static_assert(bayer_layout_fits(3, (imax + 1) / 9, 3, 1, false, false,
                                wide_address));
static_assert(!bayer_layout_fits(3, (imax + 1) / 9 + 1, 3, 1, false, false,
                                 wide_address));
static_assert(bayer_layout_fits(2, (imax + 1) / 8, 4, 1, false, false,
                                wide_address));
static_assert(!bayer_layout_fits(2, (imax + 1) / 8 + 1, 4, 1, false, false,
                                 wide_address));
// EA does not evaluate signed total row products and is not bounded to C4.
static_assert(bayer_layout_fits(4, imax / 3, 3, 1, false, true,
                                wide_address));
static_assert(!bayer_layout_fits(4, imax / 3 + 1, 3, 1, false, true,
                                 wide_address));
static_assert(bayer_layout_fits(8, imax / 147 - 4, 3, 1, true, false,
                                wide_address));
static_assert(!bayer_layout_fits(8, imax / 147 - 3, 3, 1, true, false,
                                 wide_address));
static_assert(!bayer_layout_fits(8, imax - 3, 3, 1, true, false,
                                 wide_address));
static_assert(!bayer_layout_fits(imax - 3, 8, 3, 1, true, false,
                                 wide_address));
// Simulated 32-bit ptrdiff_t protects UInt16 byte spans/buffer allocations.
static_assert(bayer_layout_fits(3, 100, 4, 2, false, false, 2400));
static_assert(!bayer_layout_fits(3, 100, 4, 2, false, false, 2399));
static_assert(bayer_layout_fits(8, 8, 3, 1, true, false, 3528));
static_assert(!bayer_layout_fits(8, 8, 3, 1, true, false, 3527));
static_assert(!bayer_layout_fits(8, 8, 3, 1, true, false, 143));

// Isolate padded checks even where the C3 signed output bound dominates.
static_assert(bayer_vng_layout_fits(imax / 12 - 2, 8, wide_address));
static_assert(!bayer_vng_layout_fits(imax / 12 - 1, 8, wide_address));
static_assert(!bayer_vng_layout_fits(8, imax - 3, wide_address));
static_assert(!bayer_vng_layout_fits(imax - 3, 8, wide_address));
static_assert(bayer_vng_layout_fits(8, 8, 3528));
static_assert(!bayer_vng_layout_fits(8, 8, 3527));
static_assert(!bayer_vng_layout_fits(8, 8, 143));
static_assert(bayer_source_span_fits(3, 16, 100, 216));
static_assert(!bayer_source_span_fits(3, 16, 100, 215));
static_assert(!bayer_source_span_fits(3, 16, 15, wide_address));
static_assert(bayer_source_span_fits(2, 16, imax + 1, wide_address));
static_assert(bayer_layout_fits(2, imax / 16, 4, 2, false, false, imax));
static_assert(!bayer_layout_fits(2, imax / 16 + 1, 4, 2, false, false, imax));
// Fallback never allocates VNG scratch, so does not inherit N*147 limits.
static_assert(bayer_layout_fits(7, imax / 21, 3, 1, true, false,
                                wide_address));

int main() { return 0; }