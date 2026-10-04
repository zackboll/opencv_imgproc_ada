#ifndef OPENCV_IMGPROC_YUV422_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_YUV422_LAYOUT_FITS_HPP

#include <climits>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace opencv_imgproc_detail {

constexpr uint64_t yuv422_address_limit()
{
    return static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max()) <
                   static_cast<uint64_t>(std::numeric_limits<size_t>::max())
        ? static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max())
        : static_cast<uint64_t>(std::numeric_limits<size_t>::max());
}

constexpr bool yuv422_byte_span_fits(uint64_t height, uint64_t width,
                                    uint64_t channels, uint64_t limit)
{
    // ABI safety: allocation and complete packed pointer spans must fit.
    return height > 0 && width > 0 && channels > 0 &&
           width <= limit / channels && height <= limit / (width * channels);
}

constexpr bool yuv422_source_span_fits(uint64_t rows, uint64_t row_bytes,
                                      uint64_t step, uint64_t limit)
{
    // ABI safety: manual row copies form (rows-1)*step+row_bytes.
    return rows > 0 && row_bytes > 0 && step >= row_bytes &&
           row_bytes <= limit &&
           (rows == 1 || step <= (limit - row_bytes) / (rows - 1));
}

constexpr bool yuv422_width_fits(uint64_t width)
{
    // ABI safety: 4.1 scalar pair reads i+yIdx+2 and writes two pixels;
    // odd width overruns the last pair. All tags evaluate signed 2*width.
    return width >= 2 && width % 2 == 0 && width <= uint64_t{INT_MAX} / 2;
}

constexpr bool yuv422_geometry_fits(uint64_t width, uint64_t height)
{
    // ABI safety: CPU/OpenVX width*height and RVV (width-1)*height scheduling.
    return yuv422_width_fits(width) && height > 0 &&
           height <= uint64_t{INT_MAX} / width;
}

constexpr bool yuv422_openvx_step_fits(uint64_t width, uint64_t height,
                                      uint64_t channels, bool reachable)
{
    // ABI safety: reachable 4.x OpenVX refineStep forms signed W*dcn for
    // H=1, then createAddressing casts the packed output step to vx_int32.
    // Its small-image rejection happens before either narrowing.
    constexpr uint64_t threshold = 2048U * 1536U;
    return !reachable || height == 0 ||
           width < threshold / height + (threshold % height != 0 ? 1U : 0U)
        || (channels > 0 && width <= uint64_t{INT_MAX} / channels);
}

constexpr bool yuv422_decode_fits(uint64_t width, uint64_t height,
                                 uint64_t channels, bool openvx = false,
                                 uint64_t limit = yuv422_address_limit())
{
    return (channels == 3 || channels == 4) &&
           yuv422_geometry_fits(width, height) &&
           yuv422_openvx_step_fits(width, height, channels, openvx) &&
           yuv422_byte_span_fits(height, width, 2, limit) &&
           yuv422_byte_span_fits(height, width, channels, limit);
}

constexpr bool yuv422_luma_fits(uint64_t width, uint64_t height,
                               uint64_t limit = yuv422_address_limit())
{
    // ABI safety: extractChannel's optional IPP path casts snapshot W*2
    // and destination W steps to int. It does not require even width.
    return width > 0 && width <= uint64_t{INT_MAX} / 2 &&
           yuv422_byte_span_fits(height, width, 2, limit) &&
           yuv422_byte_span_fits(height, width, 1, limit);
}

} // namespace opencv_imgproc_detail
#endif