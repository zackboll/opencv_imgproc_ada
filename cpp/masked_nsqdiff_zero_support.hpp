#ifndef OPENCV_IMGPROC_MASKED_NSQDIFF_ZERO_SUPPORT_HPP
#define OPENCV_IMGPROC_MASKED_NSQDIFF_ZERO_SUPPORT_HPP

#include <opencv2/core.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace opencv_imgproc_masked_template {
// Same packed-support proof as normalize_zero_scene. Writes Float32'Last
// (0x7F7FFFFF) instead of +0.0: a zero normalized-SQDIFF score is a perfect
// match, so the NCC writer must not be reused for publication.
// ABI safety: bypassing the write publishes native divide-by-zero payloads
// (NaN or Inf) that Min_Max_Loc cannot rank consistently across versions.
inline void publish_sqdiff_normed_zero_scene(
    const cv::Mat &image, const cv::Mat &mask, cv::Mat &result)
{
    using Word = std::uint64_t;
    const std::size_t stride = (std::size_t(image.cols) + 63) / 64 + 1;
    const std::size_t words = (std::size_t(result.cols) + 63) / 64;
    const std::size_t limit = std::min(
        std::vector<Word>().max_size(),
        std::size_t(std::numeric_limits<std::ptrdiff_t>::max()) / sizeof(Word));
    if (stride > limit / std::size_t(image.rows) || words > limit)
        throw std::length_error("masked NSQDIFF support allocation overflow");
    std::vector<Word> support(stride * std::size_t(image.rows), 0);
    std::vector<Word> included(words, 0);
    for (int y = 0; y < image.rows; ++y) {
        const float *row = image.ptr<float>(y);
        Word *packed = support.data() + std::size_t(y) * stride;
        for (int x = 0; x < image.cols; ++x)
            if (row[x] != 0.0f)
                packed[std::size_t(x) / 64] |= Word(1) << (x % 64);
    }
    const float sentinel = std::numeric_limits<float>::max();
    for (int y = 0; y < result.rows; ++y) {
        std::fill(included.begin(), included.end(), 0);
        for (int v = 0; v < mask.rows; ++v) {
            const float *weights = mask.ptr<float>(v);
            const Word *row = support.data() + std::size_t(y + v) * stride;
            for (int u = 0; u < mask.cols; ++u) {
                if (weights[u] == 0.0f)
                    continue;
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
                scores[x] = sentinel;
    }
}

// Checked scalar sum of included template squares. Canonical snapshots are
// finite 0..255, so each product is an integer. fits() keeps template area
// at or below INT_MAX, and 65025 * INT_MAX fits in uint64 below 2^53.
inline double masked_template_energy(const cv::Mat &patch, const cv::Mat &mask)
{
    std::uint64_t sum = 0;
    for (int y = 0; y < patch.rows; ++y) {
        const float *values = patch.ptr<float>(y);
        const float *weights = mask.ptr<float>(y);
        for (int x = 0; x < patch.cols; ++x) {
            if (weights[x] == 0.0f || values[x] == 0.0f)
                continue;
            const auto sample = static_cast<std::uint64_t>(values[x]);
            sum += sample * sample;
        }
    }
    return static_cast<double>(sum);
}
}  // namespace opencv_imgproc_masked_template
#endif
