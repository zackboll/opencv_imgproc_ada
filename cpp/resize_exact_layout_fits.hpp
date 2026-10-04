#ifndef OPENCV_IMGPROC_RESIZE_EXACT_LAYOUT_FITS_HPP
#define OPENCV_IMGPROC_RESIZE_EXACT_LAYOUT_FITS_HPP

#include <climits>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace opencv_imgproc_detail {

constexpr uint64_t resize_exact_address_limit()
{
    return static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max()) <
                   static_cast<uint64_t>(std::numeric_limits<size_t>::max())
        ? static_cast<uint64_t>(std::numeric_limits<std::ptrdiff_t>::max())
        : static_cast<uint64_t>(std::numeric_limits<size_t>::max());
}

constexpr bool resize_exact_layout_fits(
    uint64_t width, uint64_t height, uint64_t source_width,
    uint64_t source_height, uint64_t channels, uint64_t element_bytes,
    uint64_t fixedpoint_bytes, uint64_t source_step,
    uint64_t limit = resize_exact_address_limit())
{
    if (limit < sizeof(int) ||
        !width || !height || !source_width || !source_height || !channels ||
        !element_bytes || !fixedpoint_bytes)
        return false;

    // ABI safety: hlineResize forms signed cn*ofst[i], including the last
    // source pixel; the Area redirect also forms signed source_width*cn.
    if (source_width > uint64_t{INT_MAX} / channels)
        return false;

    // ABI safety: src+i*src_step row addresses must fit size_t/ptrdiff_t.
    const uint64_t source_scalars = source_width * channels;
    if (source_scalars > limit / element_bytes)
        return false;
    const uint64_t row_bytes = source_scalars * element_bytes;
    if (source_step < row_bytes || row_bytes > limit ||
        (source_height > 1 &&
         source_step > (limit - row_bytes) / (source_height - 1)))
        return false;

    // ABI safety: linebuf(2*dst_width*cn), vline widths dst_width*cn,
    // xcoeffs+2*dst_width and xcoeffs+2*dx are signed before conversion.
    if (width > uint64_t{INT_MAX} / 2 / channels)
        return false;
    // ABI safety: ycoeffs[2*dy-evalbuf_start+2+i] and 2*dst_height.
    if (height > uint64_t{INT_MAX} / 2)
        return false;
    // ABI safety: parallel_for_ evaluates signed dst_width*dst_height
    // before dividing by double(1<<16).
    if (height > uint64_t{INT_MAX} / width)
        return false;

    // ABI safety: AutoBuffer<uchar> sums (W+H)*(sizeof(int)+2*sizeof(FT));
    // only the 2*W/2*H subexpressions above are signed. Protect the size_t
    // sum and subsequent typed pointer offsets, not an arbitrary size cap.
    if (fixedpoint_bytes > (limit - sizeof(int)) / 2)
        return false;
    const uint64_t coefficient_bytes = sizeof(int) + 2 * fixedpoint_bytes;
    if (width > limit / coefficient_bytes ||
        height > limit / coefficient_bytes - width)
        return false;

    // ABI safety: AutoBuffer<FT> allocates 2*W*cn*sizeof(FT); complete
    // destination row addressing covers H*W*cn*sizeof(ET).
    const uint64_t output_scalars = width * channels;
    if (output_scalars > limit / 2 / fixedpoint_bytes ||
        output_scalars > limit / element_bytes ||
        height > limit / (output_scalars * element_bytes))
        return false;

    if (channels != 2 && source_width == 2 * width &&
        source_height == 2 * height) {
        // ABI safety: the native 2x Area redirect narrows src.step to int
        // for VecOp row access, and ofs[k]=(int)(srcstep+sx*cn).
        if (source_step > uint64_t{INT_MAX} ||
            source_step / element_bytes > uint64_t{INT_MAX} - channels)
            return false;
    }
    return true;
}

} // namespace opencv_imgproc_detail
#endif