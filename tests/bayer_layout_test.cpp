#include "../cpp/bayer_layout_fits.hpp"
#include <array>

using opencv_imgproc_detail::bayer_legacy_gray_uint16_fits;
using opencv_imgproc_detail::legacy_bayer_gray_green_sum_limit;
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

static_assert(legacy_bayer_gray_green_sum_limit() == 223300);
static_assert(uint64_t{223300} * 9617 == 2147476100);
static_assert(uint64_t{223301} * 9617 == 2147485717);
static_assert(uint64_t{223300} * 9617 <= imax);
static_assert(uint64_t{223301} * 9617 > imax);

// A cross on a green center puts large values only on R/B samples. Even
// full-range values there must not trigger a blanket per-pixel restriction.
constexpr bool cross_fits(size_t rows, size_t cols, size_t y, size_t x,
                          int32_t pattern, uint16_t up, uint16_t left,
                          uint16_t right, uint16_t down)
{
    std::array<uint16_t, 81> pixels{};
    pixels[(y - 1) * cols + x] = up;
    pixels[y * cols + x - 1] = left;
    pixels[y * cols + x + 1] = right;
    pixels[(y + 1) * cols + x] = down;
    return bayer_legacy_gray_uint16_fits(pixels.data(), rows, cols, cols,
                                         pattern);
}

static_assert(cross_fits(3, 3, 1, 1, 0, 55825, 55825, 55825, 55825));
static_assert(!cross_fits(3, 3, 1, 1, 0, 55826, 55825, 55825, 55825));
static_assert(!cross_fits(3, 3, 1, 1, 2, 65535, 65535, 65535, 65535));
static_assert(cross_fits(3, 3, 1, 1, 1, 65535, 65535, 65535, 65535));
static_assert(cross_fits(3, 3, 1, 1, 3, 65535, 65535, 65535, 65535));
static_assert(cross_fits(3, 4, 1, 2, 1, 65535, 65535, 65535, 26695));
static_assert(!cross_fits(3, 4, 1, 2, 3, 65535, 65535, 65535, 26696));

constexpr bool all_centers_fit_exactly()
{
    // Independent physical tiles, not derived from the helper's selector
    // arithmetic. true means an actual red/blue CFA site.
    constexpr bool non_green[4][2][2] = {
        {{true, false}, {false, true}},  // RGGB
        {{false, true}, {true, false}},  // GRBG
        {{true, false}, {false, true}},  // BGGR
        {{false, true}, {true, false}}   // GBRG
    };
    // Odd/even widths, first-pixel skips, row toggles and final tails.
    for (size_t rows = 3; rows <= 9; ++rows)
        for (size_t cols = 3; cols <= 9; ++cols)
            for (int32_t p = 0; p < 4; ++p)
                for (size_t y = 1; y < rows - 1; ++y)
                    for (size_t x = 1; x < cols - 1; ++x) {
                        if (!cross_fits(rows, cols, y, x, p,
                                        55825, 55825, 55825, 55825))
                            return false;
                        const bool executed = non_green[p][y % 2][x % 2];
                        if (cross_fits(rows, cols, y, x, p,
                                       55826, 55825, 55825, 55825) == executed)
                            return false;
                        if (cross_fits(rows, cols, y, x, p,
                                       65535, 65535, 65535, 65535) == executed)
                            return false;
                    }
    return true;
}

int main() { return all_centers_fit_exactly() ? 0 : 1; }