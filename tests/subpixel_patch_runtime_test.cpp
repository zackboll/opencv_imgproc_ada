// Linux/ELF wrapping observes the production call, then forwards to OpenCV.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <stdexcept>

namespace {
int calls = 0, direct_calls = 0, guarded_calls = 0;
const cv::Mat *original = nullptr;
cv::Size expected_size;
cv::Point2f expected_center;
opencv_imgproc_subpixel::Guard expected_guard;
void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
struct Mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *value = nullptr;
    explicit Mat(const cv::Mat &m) {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK, "create");
        require(opencv_core_module_output_mat(handle, &value) == OPENCV_CORE_OK,
                "resolve");
        *value = m;
    }
    ~Mat() { opencv_core_mat_destroy(handle); }
    Mat(const Mat &) = delete;
    Mat &operator=(const Mat &) = delete;
};
void exercise(const cv::Mat &image, cv::Size size, cv::Point2f center,
              int selector) {
    Mat source(image), output(cv::Mat{});
    original = source.value;
    expected_size = size;
    expected_center = center;
    const int depth = selector ? CV_32F : image.depth();
    require(opencv_imgproc_subpixel::plan(image.cols, image.rows,
                size.width, size.height, center.x, center.y, image.channels(),
                int(image.elemSize1()), depth == CV_32F ? 4 : 1,
                image.depth() == CV_8U && depth == CV_32F, expected_guard),
            "fixture plan");
    const cv::Mat before = image.clone();
    const int previous = calls;
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                size.width, size.height, center.x, center.y, selector,
                output.handle) == OPENCV_IMGPROC_OK, "production success");
    require(calls == previous + 1, "one call");
    require(output.value->size() == size && output.value->depth() == depth &&
                output.value->channels() == image.channels(), "metadata");
    require(output.value->data != image.data, "fresh result");
    require(cv::norm(image, before, cv::NORM_INF) == 0, "unchanged source");
    for (int y = 0; y < size.height; ++y) {
        for (int x = 0; x < size.width; ++x) {
            const float sx = center.x - (size.width - 1) * 0.5f + x;
            const float sy = center.y - (size.height - 1) * 0.5f + y;
            const int ix = cvFloor(sx), iy = cvFloor(sy);
            const float a = sx - ix, b = sy - iy;
            for (int c = 0; c < image.channels(); ++c) {
                auto sample = [&](int xx, int yy) {
                    xx = std::max(0, std::min(image.cols - 1, xx));
                    yy = std::max(0, std::min(image.rows - 1, yy));
                    return image.depth() == CV_8U ?
                        float(image.ptr<uchar>(yy)[xx * image.channels() + c]) :
                        image.ptr<float>(yy)[xx * image.channels() + c];
                };
                const float expected = (1-a)*(1-b)*sample(ix, iy) +
                    a*(1-b)*sample(ix+1, iy) +
                    (1-a)*b*sample(ix, iy+1) + a*b*sample(ix+1, iy+1);
                const int index = x * image.channels() + c;
                const float actual = depth == CV_8U ?
                    float(output.value->ptr<uchar>(y)[index]) :
                    output.value->ptr<float>(y)[index];
                require(std::abs(actual - expected) < 0.01f, "bilinear oracle");
            }
        }
    }
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                0, 1, center.x, center.y, selector, output.handle) !=
                OPENCV_IMGPROC_OK, "invalid rejected");
    require(calls == previous + 1, "invalid zero calls");
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                1, 1, center.x, center.y, selector, source.handle) !=
                OPENCV_IMGPROC_OK, "identity rejected");
    require(calls == previous + 1, "identity zero calls");
    const cv::Mat published = output.value->clone();
    for (const auto &bad : {cv::Point2f(-1, 0), {float(image.cols), 0},
                            {std::numeric_limits<float>::infinity(), 0},
                            {std::numeric_limits<float>::quiet_NaN(), 0}}) {
        require(opencv_imgproc_extract_subpixel_patch(source.handle,
                    1, 1, bad.x, bad.y, selector, output.handle) !=
                    OPENCV_IMGPROC_OK, "invalid center rejected");
    }
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                1, 1, center.x, center.y, 2, output.handle) !=
                OPENCV_IMGPROC_OK, "selector rejected");
    require(opencv_imgproc_extract_subpixel_patch(nullptr,
                1, 1, center.x, center.y, 0, output.handle) !=
                OPENCV_IMGPROC_OK, "null source rejected");
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                1, 1, center.x, center.y, 0, nullptr) !=
                OPENCV_IMGPROC_OK, "null destination rejected");
    require(calls == previous + 1, "all invalid zero calls");
    require(cv::norm(*output.value, published, cv::NORM_INF) == 0,
            "failure atomicity");
    // Distinct headers initially sharing Source storage may be rebound.
    *output.value = image;
    require(opencv_imgproc_extract_subpixel_patch(source.handle,
                size.width, size.height, center.x, center.y, selector,
                output.handle) == OPENCV_IMGPROC_OK, "shared destination");
    require(calls == previous + 2 && output.value->data != image.data,
            "shared destination one call and fresh storage");
    require(cv::norm(image, before, cv::NORM_INF) == 0,
            "shared destination preserves Source");
}
}

extern "C" void real_subpix(const cv::_InputArray &, cv::Size, cv::Point2f,
                             const cv::_OutputArray &, int)
    asm("__real__ZN2cv13getRectSubPixERKNS_11_InputArrayENS_5Size_IiEENS_6Point_IfEERKNS_12_OutputArrayEi");
extern "C" void wrap_subpix(const cv::_InputArray &, cv::Size, cv::Point2f,
                             const cv::_OutputArray &, int)
    asm("__wrap__ZN2cv13getRectSubPixERKNS_11_InputArrayENS_5Size_IiEENS_6Point_IfEERKNS_12_OutputArrayEi");
extern "C" void wrap_subpix(const cv::_InputArray &input, cv::Size size,
                             cv::Point2f center, const cv::_OutputArray &output,
                             int depth) {
    ++calls;
    const cv::Mat m = input.getMat();
    require(m.size() == original->size() && m.type() == original->type(),
            "unchanged logical geometry/type");
    require(size == expected_size && center == expected_center,
            "unchanged center/patch");
    if (expected_guard.direct) {
        ++direct_calls;
        require(m.data == original->data, "direct source");
    } else {
        ++guarded_calls;
        require(m.datastart != original->datastart && m.u != nullptr,
                "private owning allocation");
        cv::Size whole;
        cv::Point offset;
        m.locateROI(whole, offset);
        require(offset.x >= expected_guard.left &&
                offset.y >= expected_guard.top &&
                whole.width - offset.x - m.cols >= expected_guard.right &&
                whole.height - offset.y - m.rows >= expected_guard.bottom,
                "physical sample interval covered");
    }
    real_subpix(input, size, center, output, depth);
}

int main() {
    try {
        // Exactly sized caller storage, with no accidental hidden guards.
        uchar bytes[16];
        cv::Mat external(4, 4, CV_8UC1, bytes);
        for (int y = 0; y < 4; ++y)
            for (int x = 0; x < 4; ++x) bytes[y*4+x] = uchar(y*40+x*8);
        exercise(external, {3,3}, {0,0}, 0);
        exercise(external, {1,1}, {3,3}, 0);
        Mat empty(cv::Mat{}), destination(cv::Mat(2,2,CV_8UC1,cv::Scalar(71)));
        for (const auto &bad_image : {cv::Mat{}, cv::Mat(2,2,CV_16UC1),
                                     cv::Mat(2,2,CV_8UC2)}) {
            *empty.value = bad_image;
            const int previous = calls;
            require(opencv_imgproc_extract_subpixel_patch(empty.handle,
                        1,1,0,0,0,destination.handle) != OPENCV_IMGPROC_OK,
                    "malformed source rejected");
            require(calls == previous && destination.value->at<uchar>(0,0) == 71,
                    "malformed source zero calls/atomicity");
        }
        const int dimensions[] = {2,2,2};
        *empty.value = cv::Mat(3, dimensions, CV_8UC1);
        require(opencv_imgproc_extract_subpixel_patch(empty.handle,
                    1,1,0,0,0,destination.handle) != OPENCV_IMGPROC_OK,
                "ND rejected");
        for (int channels : {1,3}) for (int depth : {CV_8U,CV_32F}) {
            cv::Mat m(4, 4, CV_MAKETYPE(depth, channels));
            for (int y = 0; y < 4; ++y) for (int x = 0; x < 4; ++x)
                for (int c = 0; c < channels; ++c) {
                    if (depth == CV_8U)
                        m.ptr<uchar>(y)[x*channels+c] = uchar(y*40+x*8+c*4);
                    else m.ptr<float>(y)[x*channels+c] = float(y*40+x*8+c*4);
                }
            for (int selector : {0,1}) {
                exercise(m, {1,1}, {1.25f,1.25f}, selector);
                exercise(m, {2,2}, {1.5f,1.5f}, selector);
                exercise(m, {1,2}, {1.5f,1.5f}, selector);
                exercise(m, {2,1}, {1.5f,1.5f}, selector);
                for (const auto &center : {cv::Point2f(0,0), {3,0}, {0,3},
                                         {3,3}, {0.25f,1.25f}, {2.75f,1.25f},
                                         {1.25f,0.25f}, {1.25f,2.75f}})
                    exercise(m, {3,3}, center, selector);
                exercise(m, {7,3}, {1,1}, selector);
                exercise(m, {3,7}, {1,1}, selector);
                exercise(m, {7,7}, {1,1}, selector);
                cv::Mat parent(6,6,m.type(),cv::Scalar::all(250));
                cv::Mat region = parent(cv::Rect(1,1,4,4));
                m.copyTo(region);
                exercise(region, {7,7}, {0.25f,0.25f}, selector);
                parent.row(0).setTo(cv::Scalar::all(200));
                parent.col(0).setTo(cv::Scalar::all(200));
                exercise(region, {7,7}, {0.25f,0.25f}, selector);
            }
        }
        std::cout << "native calls=" << calls << " direct=" << direct_calls
                  << " guarded=" << guarded_calls << '\n';
        std::cout << "IPP enabled=" << cv::ipp::useIPP() << '\n';
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}