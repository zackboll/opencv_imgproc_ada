#ifndef OPENCV_IMGPROC_YUV420_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_YUV420_LAYOUT_FITS_HPP

#include <climits>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace opencv_imgproc_detail {

constexpr uint64_t yuv420_address_limit()
{
    return static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max()) <
                   static_cast<uint64_t>(std::numeric_limits<size_t>::max())
        ? static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max())
        : static_cast<uint64_t>(std::numeric_limits<size_t>::max());
}

constexpr bool yuv420_byte_span_fits(uint64_t rows, uint64_t cols,
                                    uint64_t channels, uint64_t limit)
{
    return rows > 0 && cols > 0 && channels > 0 &&
           cols <= limit / channels && rows <= limit / (cols * channels);
}

constexpr bool yuv420_source_span_fits(uint64_t rows, uint64_t row_bytes,
                                      uint64_t step, uint64_t limit)
{
    // ABI safety: manual snapshot copies form (rows-1)*step+row_bytes.
    return rows > 0 && row_bytes > 0 && step >= row_bytes &&
           row_bytes <= limit &&
           (rows == 1 || step <= (limit - row_bytes) / (rows - 1));
}

constexpr uint64_t yuv420_logical_height(uint64_t packed_rows)
{
    return (packed_rows / 3) * 2;
}

constexpr bool yuv420_packed_rows_fit(uint64_t rows)
{
    // ABI safety: CvtHelper FROM_YUV evaluates signed rows*2 before /3.
    return rows >= 3 && rows % 3 == 0 && rows <= uint64_t{INT_MAX} / 2;
}

constexpr bool yuv420_encode_rows_fit(uint64_t height)
{
    // ABI safety: CvtHelper TO_YUV evaluates signed (height/2)*3.
    return height >= 2 && height % 2 == 0 &&
           height / 2 <= uint64_t{INT_MAX} / 3;
}

constexpr bool yuv420_geometry_fits(uint64_t width, uint64_t height)
{
    // ABI safety: pair loops access both pixels/rows of each 2x2 block;
    // signed W*H scheduling and RVV (W-1)*H must not overflow. W>=2 also
    // bounds the encoder's signed sRow+H (at most 2*H-2).
    return width >= 2 && height >= 2 && width % 2 == 0 && height % 2 == 0 &&
           width <= uint64_t{INT_MAX} / height;
}

constexpr bool yuv420_encode_index_fits(uint64_t width, uint64_t channels)
{
    // ABI safety: last scalar color index is (W-1)*scn+2. The ignored C4
    // alpha byte need not fit signed int. SIMD load-start indices are smaller.
    return width >= 2 && (channels == 3 || channels == 4) &&
           width - 1 <= (uint64_t{INT_MAX} - 2) / channels;
}

constexpr bool yuv420_plane_relation_fits(uint64_t width, uint64_t height,
                                         uint64_t uv_width, uint64_t uv_height)
{
    // ABI safety: native pair CV_Assert multiplies signed UV dimensions by 2.
    return uv_width > 0 && uv_height > 0 &&
           uv_width <= uint64_t{INT_MAX} / 2 &&
           uv_height <= uint64_t{INT_MAX} / 2 &&
           width == uv_width * 2 && height == uv_height * 2;
}

constexpr bool yuv420_packed_fits(uint64_t rows, uint64_t width,
                                 uint64_t output_channels,
                                 uint64_t limit = yuv420_address_limit())
{
    if (!yuv420_packed_rows_fit(rows) || width < 2 || width % 2 != 0 ||
        width > uint64_t{INT_MAX} ||
        (output_channels != 1 && output_channels != 3 && output_channels != 4))
        return false;
    const uint64_t height = yuv420_logical_height(rows);
    // ABI safety: reachable OpenVX RGB/RGBX output addressing narrows row
    // step to vx_int32. Luma's copy uses W<=INT_MAX already.
    return width <= uint64_t{INT_MAX} / output_channels &&
           (output_channels == 1 || yuv420_geometry_fits(width, height)) &&
           yuv420_byte_span_fits(rows, width, 1, limit) &&
           yuv420_byte_span_fits(height, width, output_channels, limit);
}

constexpr bool yuv420_pair_fits(uint64_t height, uint64_t width,
                               uint64_t uv_height, uint64_t uv_width,
                               uint64_t output_channels,
                               uint64_t limit = yuv420_address_limit())
{
    // ABI safety: Ex OpenVX decode also narrows RGB/RGBX row step.
    return (output_channels == 3 || output_channels == 4) &&
           width <= uint64_t{INT_MAX} / output_channels &&
           yuv420_geometry_fits(width, height) &&
           yuv420_plane_relation_fits(width, height, uv_width, uv_height) &&
           yuv420_byte_span_fits(height, width, 1, limit) &&
           yuv420_byte_span_fits(uv_height, uv_width, 2, limit) &&
           yuv420_byte_span_fits(height, width, output_channels, limit);
}

constexpr bool yuv420_encode_fits(uint64_t height, uint64_t width,
                                 uint64_t channels,
                                 uint64_t limit = yuv420_address_limit())
{
    return yuv420_geometry_fits(width, height) &&
           yuv420_encode_rows_fit(height) &&
           yuv420_encode_index_fits(width, channels) &&
           yuv420_byte_span_fits(height, width, channels, limit) &&
           yuv420_byte_span_fits((height / 2) * 3, width, 1, limit);
}

} // namespace opencv_imgproc_detail
#endif