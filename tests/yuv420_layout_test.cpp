#include "../cpp/yuv420_layout_fits.hpp"

using namespace opencv_imgproc_detail;
constexpr uint64_t imax = INT_MAX;
constexpr uint64_t wide = INT64_MAX;
constexpr uint64_t packed_max = (imax / 2 / 3) * 3;
static_assert(yuv420_packed_rows_fit(packed_max));
static_assert(!yuv420_packed_rows_fit(packed_max + 3));
static_assert(!yuv420_packed_rows_fit(4));
static_assert(!yuv420_packed_rows_fit(0));
static_assert(yuv420_logical_height(3) == 2);
static_assert(yuv420_logical_height(packed_max) == packed_max / 3 * 2);
static_assert(yuv420_encode_rows_fit((imax / 3) * 2));
static_assert(!yuv420_encode_rows_fit((imax / 3) * 2 + 2));
static_assert(!yuv420_encode_rows_fit(3));
static_assert(yuv420_geometry_fits(2, (imax / 2 / 2) * 2));
static_assert(!yuv420_geometry_fits(2, (imax / 2 / 2) * 2 + 2));
static_assert(!yuv420_geometry_fits(3, 2));
static_assert(!yuv420_geometry_fits(2, 1));
static_assert(yuv420_encode_index_fits((imax - 2) / 3 + 1, 3));
static_assert(!yuv420_encode_index_fits((imax - 2) / 3 + 2, 3));
static_assert(yuv420_encode_index_fits((imax - 2) / 4 + 1, 4));
static_assert(!yuv420_encode_index_fits((imax - 2) / 4 + 2, 4));
static_assert(!yuv420_encode_index_fits(2, 2));
static_assert(yuv420_plane_relation_fits(4, 6, 2, 3));
static_assert(!yuv420_plane_relation_fits(4, 6, 3, 3));
static_assert(!yuv420_plane_relation_fits(4, 6, 2, 4));
static_assert(!yuv420_plane_relation_fits(imax, 2, imax / 2 + 1, 1));
static_assert(!yuv420_plane_relation_fits(2, imax, 1, imax / 2 + 1));
static_assert(yuv420_byte_span_fits(3, 4, 4, 48));
static_assert(!yuv420_byte_span_fits(3, 4, 4, 47));
static_assert(!yuv420_byte_span_fits(1, UINT64_MAX, 4, wide));
static_assert(!yuv420_byte_span_fits(UINT64_MAX, 2, 1, wide));
static_assert(yuv420_source_span_fits(3, 4, 100, 204));
static_assert(!yuv420_source_span_fits(3, 4, 100, 203));
static_assert(!yuv420_source_span_fits(3, 4, 3, wide));
static_assert(yuv420_source_span_fits(2, 4, imax + 1, wide));
static_assert(!yuv420_source_span_fits(2, 4, UINT64_MAX, wide));
static_assert(yuv420_packed_fits(3, 2, 3, 12));
static_assert(!yuv420_packed_fits(3, 2, 3, 11));
static_assert(yuv420_packed_fits(3, 2, 4, 16));
static_assert(!yuv420_packed_fits(3, 2, 4, 15));
static_assert(yuv420_packed_fits(3, 2, 1, 6));
static_assert(!yuv420_packed_fits(3, 2, 1, 5));
static_assert(yuv420_pair_fits(2, 2, 1, 1, 4, 16));
static_assert(!yuv420_pair_fits(2, 2, 1, 1, 4, 15));
static_assert(!yuv420_pair_fits(2, 2, 1, 2, 3));
static_assert(yuv420_encode_fits(2, 2, 3, 12));
static_assert(!yuv420_encode_fits(2, 2, 3, 11));
static_assert(yuv420_encode_fits(2, 2, 4, 16));
static_assert(!yuv420_encode_fits(2, 2, 4, 15));
static_assert(!yuv420_encode_fits(2, 2, 1));
// C4's last RGB index fits even though the packed row size is INT_MAX+1.
static_assert(yuv420_encode_fits(2, (imax + 1) / 4, 4, wide));
static_assert(!yuv420_encode_fits(2, (imax + 1) / 4 + 2, 4, wide));
static_assert(!yuv420_encode_fits((imax / 3) * 2 + 2, 2, 3, wide));
static_assert(!yuv420_packed_fits(packed_max + 3, 2, 1, wide));
static_assert(!yuv420_packed_fits(3, 3, 3));
static_assert(!yuv420_packed_fits(3, 2, 2));
static_assert(yuv420_packed_fits(3, (imax / 4 / 2) * 2, 4, wide));
static_assert(!yuv420_packed_fits(3, (imax / 4 / 2) * 2 + 2, 4, wide));
static_assert(yuv420_pair_fits(2, (imax / 3 / 2) * 2, 1,
                             (imax / 3 / 2), 3, wide));
static_assert(!yuv420_pair_fits(2, (imax / 3 / 2) * 2 + 2, 1,
                              (imax / 3 / 2) + 1, 3, wide));
int main() { return 0; }