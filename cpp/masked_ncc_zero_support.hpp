#ifndef OPENCV_IMGPROC_MASKED_NCC_ZERO_SUPPORT_HPP
#define OPENCV_IMGPROC_MASKED_NCC_ZERO_SUPPORT_HPP

#include <opencv2/core.hpp>
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace opencv_imgproc_masked_template {
// Internal: owning C1 Float32 snapshots and result, preflighted by fits().
// OR shifted nonzero-support bits, not intensities or floating correlations.
inline void normalize_zero_scene(const cv::Mat &image, const cv::Mat &mask,
                                 cv::Mat &result)
{
    using Word = std::uint64_t;
    const std::size_t stride = (std::size_t(image.cols) + 63) / 64 + 1;
    const std::size_t words = (std::size_t(result.cols) + 63) / 64;
    // ABI safety: the packed allocation and row offsets must fit size_t,
    // ptrdiff_t and vector capacity before multiplication/allocation.
    const std::size_t limit = std::min(
        std::vector<Word>().max_size(),
        std::size_t(std::numeric_limits<std::ptrdiff_t>::max()) / sizeof(Word));
    if (stride > limit / std::size_t(image.rows) || words > limit)
        throw std::length_error("masked NCC support allocation overflow");
    std::vector<Word> support(stride * std::size_t(image.rows), 0);
    std::vector<Word> included(words, 0);
    for (int y = 0; y < image.rows; ++y) {
        const float *row = image.ptr<float>(y);
        Word *packed = support.data() + std::size_t(y) * stride;
        for (int x = 0; x < image.cols; ++x)
            if (row[x] != 0.0f)
                packed[std::size_t(x) / 64] |= Word(1) << (x % 64);
    }
    for (int y = 0; y < result.rows; ++y) {
        std::fill(included.begin(), included.end(), 0);
        for (int v = 0; v < mask.rows; ++v) {
            const float *weights = mask.ptr<float>(v);
            const Word *row = support.data() + std::size_t(y + v) * stride;
            for (int u = 0; u < mask.cols; ++u) {
                if (weights[u] == 0.0f) continue;
                const std::size_t offset = std::size_t(u) / 64;
                const unsigned shift = unsigned(u % 64);
                for (std::size_t w = 0; w < words; ++w) {
                    // ABI safety: valid output extent gives y+v < image.rows
                    // and offset+w < stride-1. The final zero padding word
                    // permits the cross-word read; shift==0 avoids shift by 64.
                    Word bits = row[offset + w] >> shift;
                    if (shift != 0)
                        bits |= row[offset + w + 1] << (64 - shift);
                    included[w] |= bits;
                }
            }
        }
        float *scores = result.ptr<float>(y);
        for (int x = 0; x < result.cols; ++x)
            if ((included[std::size_t(x) / 64] & (Word(1) << (x % 64))) == 0)
                scores[x] = 0.0f;
    }
}
} // namespace opencv_imgproc_masked_template
#endif
