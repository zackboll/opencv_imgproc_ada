// Real production shim and real Core-owned handles. Linker wrapping observes
// every call from this shim to the unmodified native spatialGradient symbol.
// No fake implementation, production override, or public adapter flag.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <stdexcept>

namespace {
int native_calls = 0;
int expected_width = 0;

void require(bool condition, const char *message)
{
    if (!condition) throw std::runtime_error(message);
}

struct test_mat {
    opencv_core_mat_handle *handle = nullptr;
    cv::Mat *mat = nullptr;
    explicit test_mat(const cv::Mat &value)
    {
        require(opencv_core_mat_create(&handle) == OPENCV_CORE_OK,
                "Core wrapper allocation");
        if (opencv_core_module_output_mat(handle, &mat) != OPENCV_CORE_OK) {
            opencv_core_mat_destroy(handle);
            throw std::runtime_error("Core output bridge");
        }
        *mat = value;
    }
    test_mat(const test_mat &) = delete;
    test_mat &operator=(const test_mat &) = delete;
    ~test_mat() { opencv_core_mat_destroy(handle); }
};

void equal(const cv::Mat &a, const cv::Mat &b)
{
    require(a.size() == b.size() && a.type() == b.type(), "result metadata");
    require(cv::norm(a, b, cv::NORM_INF) == 0, "exact Sobel equivalence");
}

void exercise(const cv::Mat &image)
{
    test_mat source(image), x(cv::Mat{}), y(cv::Mat{});
    const cv::Mat before = image.clone();
    for (const int32_t border : {int32_t{1}, int32_t{3}}) {
        expected_width = image.cols == 1 ? 2 : image.cols;
        const int old_calls = native_calls;
        require(opencv_imgproc_spatial_gradient(source.handle, border,
                    x.handle, y.handle) == OPENCV_IMGPROC_OK, "shim success");
        require(native_calls == old_calls + 1, "exactly one native call");
        const int native_border = border == 1 ? cv::BORDER_REPLICATE :
                                               cv::BORDER_REFLECT_101;
        cv::Mat sx, sy;
        // Isolated Sobel is a test oracle, never production implementation.
        cv::Sobel(image, sx, CV_16S, 1, 0, 3, 1, 0,
                  native_border | cv::BORDER_ISOLATED);
        cv::Sobel(image, sy, CV_16S, 0, 1, 3, 1, 0,
                  native_border | cv::BORDER_ISOLATED);
        equal(*x.mat, sx);
        equal(*y.mat, sy);
        equal(image, before);
        require(x.mat->data != y.mat->data && x.mat->data != image.data &&
                y.mat->data != image.data, "fresh independent allocations");
        if (image.cols == 1) {
            for (int row = 0; row < image.rows; ++row)
                require(x.mat->ptr<short>(row)[0] == 0, "one-column X zero");
        }
    }
    const cv::Mat old_x = x.mat->clone(), old_y = y.mat->clone();
    const int old_calls = native_calls;
    require(opencv_imgproc_spatial_gradient(source.handle, 99,
                x.handle, y.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "invalid selector");
    require(opencv_imgproc_spatial_gradient(source.handle, 3,
                x.handle, x.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "same output object");
    require(opencv_imgproc_spatial_gradient(source.handle, 3,
                source.handle, y.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "source X identity");
    require(opencv_imgproc_spatial_gradient(source.handle, 3,
                x.handle, source.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "source Y identity");
    require(opencv_imgproc_spatial_gradient(nullptr, 3,
                x.handle, y.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "null source");
    require(opencv_imgproc_spatial_gradient(source.handle, 3,
                nullptr, y.handle) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "null X");
    require(opencv_imgproc_spatial_gradient(source.handle, 3,
                x.handle, nullptr) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
            "null Y");
    require(native_calls == old_calls, "invalid calls never enter native code");
    equal(*x.mat, old_x);
    equal(*y.mat, old_y);
    equal(image, before);
}
} // namespace

extern "C" void real_gradient(cv::InputArray, cv::OutputArray, cv::OutputArray,
                              int, int)
    asm("__real__ZN2cv15spatialGradientERKNS_11_InputArrayERKNS_12_OutputArrayES5_ii");
extern "C" void observed_gradient(cv::InputArray, cv::OutputArray,
                                  cv::OutputArray, int, int)
    asm("__wrap__ZN2cv15spatialGradientERKNS_11_InputArrayERKNS_12_OutputArrayES5_ii");
extern "C" void observed_gradient(cv::InputArray src, cv::OutputArray dx,
                                  cv::OutputArray dy, int ksize, int border)
{
    const cv::Mat input = src.getMat();
    require(input.cols >= 2, "UNSAFE native width-one call");
    require(input.cols == expected_width, "native direct/adapter geometry");
    require(ksize == 3, "fixed kernel");
    ++native_calls;
    real_gradient(src, dx, dy, ksize, border);
}

int main()
{
    try {
        // Exactly sized external inputs make adapter overreads observable.
        uchar sole[] = {71};
        exercise(cv::Mat(1, 1, CV_8UC1, sole));
        uchar column[] = {0, 10, 20, 30, 40, 50, 60};
        exercise(cv::Mat(7, 1, CV_8UC1, column));
        for (const int rows : {1, 2, 7}) {
            for (const int cols : {2, 19}) {
                cv::Mat image(rows, cols, CV_8UC1);
                for (int r = 0; r < rows; ++r)
                    for (int c = 0; c < cols; ++c)
                        image.ptr<uchar>(r)[c] =
                            static_cast<uchar>((r * 79 + c * 53) % 256);
                exercise(image);
            }
        }
        cv::Mat parent(7, 3, CV_8UC1);
        for (int r = 0; r < parent.rows; ++r) {
            parent.ptr<uchar>(r)[0] = static_cast<uchar>(200 + r);
            parent.ptr<uchar>(r)[1] = static_cast<uchar>(10 * (r + 1));
            parent.ptr<uchar>(r)[2] = static_cast<uchar>(250 + r % 6);
        }
        const cv::Mat before = parent.clone();
        exercise(parent(cv::Rect(1, 1, 1, 5)));
        equal(parent, before);
        std::cout << "OpenCV " << CV_VERSION << ": " << native_calls
                  << " observed native calls; all widths >= 2; PASS\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}