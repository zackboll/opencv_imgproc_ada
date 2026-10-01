#ifndef OPENCV_IMGPROC_EMD_SIGNATURE_INDEX_FITS_HPP
#define OPENCV_IMGPROC_EMD_SIGNATURE_INDEX_FITS_HPP

#include <climits>
#include <cstdint>

// ABI safety: OpenCV 4.1 icvInitEMD reads signature[i * (dims + 1)]
// for every row; built-in metrics also form signature + ci * (dims + 1) + 1.
// dims + 1 is cols, and ci indexes an original (possibly last) row.
// Explicit user costs never form the coordinate pointer.
inline bool emd_signature_index_fits(int rows, int cols,
                                     bool built_in_metric) noexcept
{
    if (rows <= 0 || cols <= 0) return false;
    const std::uint64_t base = static_cast<std::uint64_t>(rows - 1) *
                               static_cast<std::uint64_t>(cols);
    return base + (built_in_metric ? 1U : 0U) <=
           static_cast<std::uint64_t>(INT_MAX);
}

#endif
