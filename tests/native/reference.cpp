#include "opencv_core_module_bridge.hpp"
#include <opencv2/imgproc.hpp>
#include <opencv2/core/utility.hpp>
#include <cstdint>

// Test-only C ABI. Runtime library version, not caller-provided configuration.
extern "C" int32_t imgproc_test_native_version() noexcept
{
    try {
        const int major=cv::getVersionMajor(), minor=cv::getVersionMinor();
        const int revision=cv::getVersionRevision();
        if (major!=CV_VERSION_MAJOR || minor!=CV_VERSION_MINOR || revision!=CV_VERSION_REVISION)
            return -1;
        return major*10000+minor*100+revision;
    } catch (...) { return -1; }
}

// Independent numeric native selectors, never production bayer_code().
// Compare every pixel including borders against the same native operation.
extern "C" int32_t imgproc_test_bayer_reference(
    const opencv_core_mat_handle *source, const opencv_core_mat_handle *output,
    int32_t pattern, int32_t method, int32_t order) noexcept
{
    try {
        const cv::Mat *src=nullptr, *actual=nullptr;
        if (opencv_core_module_input_mat(source,&src)!=OPENCV_CORE_OK || !src ||
            opencv_core_module_input_mat(output,&actual)!=OPENCV_CORE_OK || !actual ||
            pattern<0 || pattern>3 || method<0 || method>2 || order<0 || order>1)
            return -1;
        const int codes[3][2][4]={
            {{46,47,48,49},{48,49,46,47}},
            {{62,63,64,65},{64,65,62,63}},
            {{135,136,137,138},{137,138,135,136}}};
        cv::Mat expected;
        cv::demosaicing(src->clone(),expected,codes[method][order][pattern],3);
        if (actual->size()!=expected.size() || actual->type()!=expected.type()) return 0;
        return cv::norm(*actual,expected,cv::NORM_INF)==0 ? 1 : 0;
    } catch (...) { return -1; }
}