// Task 053 independent native probe (no production shim).
// Compares, per exact OpenCV version:
//   N  native masked TM_CCOEFF           (4.10 / 5.0 only; 4.1 must throw)
//   C  composition with unmasked TM_CCORR (all versions)
//   X  composition WITHOUT residual correction
//   O  exact integer oracle  STI - ST*SI/n
// Also reports all-zero, one-pixel and constant-template behavior.
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>

static cv::Mat compose(const cv::Mat &img, const cv::Mat &tpl,
                       const cv::Mat &mask, bool correct)
{
    const cv::Scalar n = cv::sum(mask);
    const cv::Scalar mean =
        cv::Scalar::all(cv::sum(mask.mul(tpl))[0] / n[0]);
    cv::Mat centered = mask.mul(mask.mul(tpl - mean));
    cv::Mat a, b;
    cv::matchTemplate(img, centered, a, cv::TM_CCORR);
    if (!correct)
        return a;
    cv::matchTemplate(img, mask, b, cv::TM_CCORR);
    cv::Mat scaled, out;
    cv::multiply(b, cv::Scalar(cv::sum(centered)[0] / n[0]), scaled);
    cv::subtract(a, scaled, out);
    return out;
}

static double oracle(const cv::Mat &s, const cv::Mat &t, const cv::Mat &m,
                     int y, int x)
{
    std::uint64_t n = 0, st = 0, si = 0, sti = 0;
    for (int v = 0; v < t.rows; ++v)
        for (int u = 0; u < t.cols; ++u) {
            if (!m.at<uchar>(v, u))
                continue;
            const std::uint64_t tv = t.at<uchar>(v, u);
            const std::uint64_t iv = s.at<uchar>(y + v, x + u);
            ++n; st += tv; si += iv; sti += tv * iv;
        }
    if (n == 0)
        return 0.0;
    return (double)sti - (long double)st * (long double)si / (long double)n;
}

static void report(const char *name, const cv::Mat &s8, const cv::Mat &t8,
                   const cv::Mat &m8)
{
    cv::Mat s, t, m;
    s8.convertTo(s, CV_32F);
    t8.convertTo(t, CV_32F);
    cv::Mat bin = m8 != 0;
    bin.convertTo(m, CV_32F, 1.0 / 255.0);
    cv::Mat comp = compose(s, t, m, true), nocorr = compose(s, t, m, false);
    cv::Mat native;
    bool have = true;
    try {
        cv::matchTemplate(s, t, native, cv::TM_CCOEFF, m);
    } catch (const cv::Exception &) {
        have = false;
    }
    double worst_c = 0, worst_n = 0, worst_x = 0, worst_cn = 0;
    int bitdiff = 0;
    for (int y = 0; y < comp.rows; ++y)
        for (int x = 0; x < comp.cols; ++x) {
            const double o = oracle(s8, t8, m8, y, x);
            worst_c = std::fmax(worst_c, std::fabs(comp.at<float>(y, x) - o));
            worst_x = std::fmax(worst_x, std::fabs(nocorr.at<float>(y, x) - o));
            if (have) {
                worst_n = std::fmax(worst_n,
                                    std::fabs(native.at<float>(y, x) - o));
                worst_cn = std::fmax(
                    worst_cn, std::fabs(native.at<float>(y, x) -
                                        comp.at<float>(y, x)));
                std::uint32_t p, q;
                const float fa = native.at<float>(y, x), fb = comp.at<float>(y, x);
                std::memcpy(&p, &fa, 4);
                std::memcpy(&q, &fb, 4);
                bitdiff += p != q;
            }
        }
    std::printf("%-12s native=%d |C-O|=%.6g |X-O|=%.6g |N-O|=%.6g |N-C|=%.6g "
                "bit_diff=%d\n",
                name, have, worst_c, worst_x, worst_n, worst_cn, bitdiff);
}

int main()
{
    std::printf("VERSION %s\n", CV_VERSION);
    cv::Mat big(48, 64, CV_8U);
    for (int y = 0; y < big.rows; ++y)
        for (int x = 0; x < big.cols; ++x)
            big.at<uchar>(y, x) = (uchar)((y * 13 + x * 29 + (y * x) % 7) % 251);
    cv::Mat tpl = big(cv::Rect(20, 12, 11, 9)).clone();
    cv::Mat full(9, 11, CV_8U, cv::Scalar(1));
    cv::Mat sparse(9, 11, CV_8U, cv::Scalar(0));
    sparse.at<uchar>(0, 0) = 255; sparse.at<uchar>(4, 6) = 17;
    sparse.at<uchar>(8, 10) = 1; sparse.at<uchar>(3, 3) = 1;
    report("full", big, tpl, full);
    report("sparse", big, tpl, sparse);
    cv::Mat high = big + 4;  // near 255
    report("high", high, tpl + 4, sparse);
    cv::Mat inv = 255 - big;
    report("inverted", inv, tpl, full);
    cv::Mat constant(9, 11, CV_8U, cv::Scalar(100));
    report("const-templ", big, constant, full);
    cv::Mat one(9, 11, CV_8U, cv::Scalar(0));
    one.at<uchar>(4, 5) = 1;
    report("one-pixel", big, tpl, one);
    cv::Mat zero(9, 11, CV_8U, cv::Scalar(0));
    cv::Mat zs, zt, zm;
    big.convertTo(zs, CV_32F);
    tpl.convertTo(zt, CV_32F);
    zero.convertTo(zm, CV_32F);
    try {
        cv::Mat r;
        cv::matchTemplate(zs, zt, r, cv::TM_CCOEFF, zm);
        std::printf("all-zero native: score[0]=%g finite=%d\n", r.at<float>(0, 0),
                    (int)std::isfinite(r.at<float>(0, 0)));
    } catch (const cv::Exception &e) {
        std::printf("all-zero native: exception\n");
    }
    {
        cv::Mat r = compose(zs, zt, zm, true);
        std::printf("all-zero composition: score[0]=%g finite=%d\n",
                    r.at<float>(0, 0), (int)std::isfinite(r.at<float>(0, 0)));
    }
    return 0;
}
