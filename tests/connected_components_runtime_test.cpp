// Full production shims and real native implementations; no mock CCL paths.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <stdexcept>

namespace {
void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
struct Mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *value = nullptr;
    explicit Mat(const cv::Mat &image = cv::Mat()) {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK, "Core create");
        require(opencv_core_module_output_mat(handle, &value) == OPENCV_CORE_OK,
                "Core resolve");
        *value = image;
    }
    ~Mat() { opencv_core_mat_destroy(handle); }
    Mat(const Mat &) = delete;
    Mat &operator=(const Mat &) = delete;
};
void equal(const cv::Mat &a, const cv::Mat &b) {
    require(a.size() == b.size() && a.type() == b.type(), "result metadata");
    require(cv::norm(a, b, cv::NORM_INF) == 0, "native numerical reference");
}
bool unavailable(int algorithm) {
#if CV_VERSION_MAJOR == 4 && (CV_VERSION_MINOR < 5 || (CV_VERSION_MINOR == 5 && CV_VERSION_REVISION < 2))
    return algorithm == 3;
#else
    (void)algorithm;
    return false;
#endif
}
bool unsafe_parallel(int rows) {
#if CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR == 1
    return (rows & 1) && cv::getNumThreads() > 1 &&
        rows / cv::getNumThreads() >= 2;
#else
    (void)rows;
    return false;
#endif
}
bool unsafe_statistics(const cv::Mat &source) {
#if CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR == 1
    return cv::countNonZero(source) == static_cast<int>(source.total());
#else
    (void)source;
    return false;
#endif
}
int native_selector(int algorithm) {
    switch (algorithm) {
    case 1: return cv::CCL_WU;
    case 2: return cv::CCL_GRANA;
#if CV_VERSION_MAJOR > 4 || (CV_VERSION_MAJOR == 4 && (CV_VERSION_MINOR > 5 || (CV_VERSION_MINOR == 5 && CV_VERSION_REVISION >= 2)))
    case 3: return cv::CCL_SPAGHETTI;
#endif
    default: return cv::CCL_DEFAULT;
    }
}
int reference_cases = 0, rejection_cases = 0;
void references() {
    // Include both serial and parallel paths, odd/even edges, thin images,
    // parent foreground outside a noncontiguous source ROI and both depths.
    for (int rows : {1, 2, 3, 8, 17, 512, 513})
    for (int cols : {1, 2, 9, 32})
    for (int pattern : {0, 1, 2, 3})
    for (int connectivity : {4, 8})
    for (int algorithm : {0, 1, 2, 3})
    for (int depth : {0, 1}) {
        cv::Mat parent(rows + 2, cols + 4, CV_8U, cv::Scalar(255));
        cv::Mat input = parent(cv::Rect(1, 1, cols, rows));
        for (int r = 0; r < rows; ++r) for (int c = 0; c < cols; ++c)
            input.at<uchar>(r,c) = pattern == 0 ? 0 : pattern == 1 ? 127 :
                pattern == 2 ? (((r + c) % 2) ? 0 : 1) :
                ((r * 37 + c * 19) % 5 ? 0 : 255);
        const cv::Mat before = parent.clone();
        Mat src(input), dst(cv::Mat(rows, cols, CV_32S, cv::Scalar(73))), stats, centers;
        const cv::Mat old = *dst.value;
        int32_t count = -1;
        const auto run = [&](bool with_stats) {
            return with_stats ? opencv_imgproc_connected_components_with_stats_options(
                src.handle, dst.handle, stats.handle, centers.handle,
                connectivity, depth, algorithm, &count) :
                opencv_imgproc_connected_components(src.handle, dst.handle,
                    connectivity, depth, algorithm, &count);
        };
        for (bool with_stats : {false, true}) {
            const auto status = run(with_stats);
            if (unavailable(algorithm) || unsafe_parallel(rows) ||
                (with_stats && unsafe_statistics(input))) {
                require(status == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT && count == 0,
                        "explicit unsupported/unsafe rejection");
                ++rejection_cases;
                continue;
            }
            require(status == OPENCV_IMGPROC_OK, opencv_imgproc_last_error_message());
            cv::Mat expected, expected_stats, expected_centers;
            const int total = with_stats ? cv::connectedComponentsWithStats(
                input, expected, expected_stats, expected_centers, connectivity,
                CV_32S, native_selector(algorithm)) : cv::connectedComponents(
                input, expected, connectivity, CV_32S, native_selector(algorithm));
            if (depth == 0) expected.convertTo(expected, CV_16U);
            require(count == total, "native label count");
            equal(*dst.value, expected);
            if (with_stats) {
                equal(*stats.value, expected_stats);
                // Absent background centroids are NaN; compare only populated rows.
                for (int l = 0; l < total; ++l)
                    if (expected_stats.at<int>(l, cv::CC_STAT_AREA) != 0)
                        equal(centers.value->row(l), expected_centers.row(l));
            }
            equal(parent, before);
            require(old.at<int>(0,0) == 73, "old destination aliases preserved");
            ++reference_cases;
        }
    }
}
void capacity() {
    for (int algorithm : {0, 1, 2, 3}) {
        if (unavailable(algorithm)) continue;
        cv::Mat input(512, 256, CV_8U);
        for (int r = 0; r < input.rows; ++r) for (int c = 0; c < input.cols; ++c)
            input.at<uchar>(r,c) = (r + c) % 2 ? 0 : 255;
        input.at<uchar>(511,255) = 0;
        Mat src(input), dst, stats, centers;
        int32_t count = -1;
        for (bool with_stats : {false, true}) {
            const auto run = [&](int depth) {
                return with_stats ? opencv_imgproc_connected_components_with_stats_options(
                    src.handle, dst.handle, stats.handle, centers.handle,
                    4, depth, algorithm, &count) :
                    opencv_imgproc_connected_components(src.handle, dst.handle,
                        4, depth, algorithm, &count);
            };
            input.at<uchar>(511,255) = 0;
            require(run(0) == 0 && count == 65536, "UInt16 full capacity");
            const cv::Mat old = *dst.value, before = old.clone();
            input.at<uchar>(511,255) = 255;
            require(run(0) == 4 && count == 0, "UInt16 overflow rejected");
            equal(*dst.value, before); equal(old, before);
            require(run(1) == 0 && count == 65537, "Int32 capacity recovery");
            ++reference_cases; ++rejection_cases;
        }
    }
    // Large geometry, one final component: no unsafe 16-bit provisional pass.
    Mat src(cv::Mat(514, 514, CV_8U, cv::Scalar(1))), dst;
    int32_t count = 0;
    require(opencv_imgproc_connected_components(src.handle, dst.handle, 4, 0, 1,
                &count) == 0 && count == 2, "large geometry Int32 staging");
}
void malformed() {
    Mat src(cv::Mat(4, 6, CV_8U, cv::Scalar(1))),
        dst(cv::Mat(4, 6, CV_32S, cv::Scalar(31))), stats, centers;
    const cv::Mat before = dst.value->clone();
    int32_t count = -1;
    const auto reject = [&](int connectivity, int depth, int algorithm) {
        require(opencv_imgproc_connected_components(src.handle, dst.handle,
                    connectivity, depth, algorithm, &count) == 4 && count == 0,
                "invalid selector");
        equal(*dst.value, before); ++rejection_cases;
    };
    reject(0,1,0); reject(7,1,0); reject(8,-1,0); reject(8,2,0);
    reject(8,1,-1); reject(8,1,4); reject(INT_MAX,INT_MAX,INT_MAX);
    require(opencv_imgproc_connected_components(nullptr,dst.handle,8,1,0,&count)==4,
            "null source");
    require(opencv_imgproc_connected_components(src.handle,nullptr,8,1,0,&count)==4,
            "null destination");
    require(opencv_imgproc_connected_components(src.handle,dst.handle,8,1,0,nullptr)==4,
            "null count");
    require(opencv_imgproc_connected_components(src.handle,src.handle,8,1,0,&count)==4,
            "identical objects");
    Mat alias(*src.value);
    require(opencv_imgproc_connected_components(src.handle,alias.handle,8,1,0,&count)==4,
            "shallow alias");
    Mat overlap((*src.value)(cv::Rect(1,1,3,2)));
    require(opencv_imgproc_connected_components(src.handle,overlap.handle,8,1,0,&count)==4,
            "overlapping Region");
    require(opencv_imgproc_connected_components_with_stats_options(src.handle,dst.handle,
                dst.handle,centers.handle,8,1,0,&count)==4, "same output headers");
    Mat output_alias(*dst.value);
    require(opencv_imgproc_connected_components_with_stats_options(src.handle,dst.handle,
                output_alias.handle,centers.handle,8,1,0,&count)==4, "overlapping outputs");
    require(opencv_imgproc_connected_components_with_stats_options(src.handle,dst.handle,
                nullptr,centers.handle,8,1,0,&count)==4, "null statistics");
    require(opencv_imgproc_connected_components_with_stats_options(src.handle,dst.handle,
                stats.handle,nullptr,8,1,0,&count)==4, "null centroids");
    // A valid Core wrapper can still be an invalid output: temporary external
    // views cannot have their native headers rebound by a cooperating module.
    int32_t external_data[4] = {17,17,17,17};
    opencv_core_mat_handle *external = nullptr;
    require(opencv_core_mat_create_external_2d(2,2,CV_32S,1,external_data,
                sizeof(external_data),&external)==0, "external Core view");
    const auto external_status = opencv_imgproc_connected_components(
        src.handle,external,8,1,0,&count);
    opencv_core_mat_destroy(external);
    require(external_status==4 && external_data[0]==17,
            "non-rebindable output rejected without storage writes");
    for (const cv::Mat &bad : {cv::Mat(), cv::Mat(4,6,CV_32F,cv::Scalar(1)),
                              cv::Mat(4,6,CV_8UC3,cv::Scalar::all(1))}) {
        Mat input(bad);
        require(opencv_imgproc_connected_components(input.handle,dst.handle,
                    8,1,0,&count)!=0 && count==0, "empty/wrong type rejected");
        equal(*dst.value,before);
    }
    const int sizes[] = {2,3,4};
    Mat nd(cv::Mat(3,sizes,CV_8U,cv::Scalar(1)));
    require(opencv_imgproc_connected_components(nd.handle,dst.handle,8,1,0,&count)==4,
            "N-D source rejected");
    // Forge only header arithmetic for boundary rejection before any pixel
    // access. Restore headers immediately; never allocate enormous images.
    const int old_rows = src.value->rows, old_cols = src.value->cols;
    src.value->rows = INT_MAX;
    require(opencv_imgproc_connected_components(src.handle,dst.handle,8,1,0,&count)==4,
            "signed dimension overflow");
    src.value->rows = 50000; src.value->cols = 50000;
    require(opencv_imgproc_connected_components(src.handle,dst.handle,8,1,0,&count)==4,
            "signed pixel product overflow");
    src.value->rows = old_rows; src.value->cols = old_cols;
    const size_t stride = src.value->step[0];
    src.value->step[0] = SIZE_MAX;
    require(opencv_imgproc_connected_components(src.handle,dst.handle,8,1,0,&count)==4,
            "source stride overflow");
    src.value->step[0] = stride;
    equal(*dst.value,before);
    require(opencv_imgproc_connected_components(src.handle,dst.handle,8,1,0,&count)==0 &&
            count==2, "recovery after malformed ABI calls");
}
}
int main() {
    try {
        references(); capacity(); malformed();
        std::cout << "OpenCV " << CV_VERSION << ": " << reference_cases
                  << " native reference cases; " << rejection_cases
                  << " counted safety rejections; malformed ABI and recovery passed\n";
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "FAIL: " << e.what() << '\n'; return 1;
    }
}