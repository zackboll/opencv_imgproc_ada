// Full production shims, real Core-owned handles, independent native references.
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
void equal(const cv::Mat &a, const cv::Mat &b, double tolerance = 0) {
    require(a.size() == b.size() && a.type() == b.type(), "result metadata");
    require(cv::norm(a, b, cv::NORM_INF) <= tolerance, "native numerical reference");
}
int canny_cases = 0, box_cases = 0;
void canny() {
    for (int cn : {1, 3}) for (int norm : {0, 1})
    for (int rows : {1, 3, 9}) for (int cols : {1, 7, 33, 65}) {
        cv::Mat px(rows + 2, cols + 5, CV_MAKETYPE(CV_16S, cn), cv::Scalar::all(0));
        cv::Mat py = px.clone();
        cv::Mat x = px(cv::Rect(1, 1, cols, rows));
        cv::Mat y = py(cv::Rect(1, 1, cols, rows));
        for (int r = 0; r < rows; ++r) for (int c = 0; c < cols * cn; ++c) {
            x.ptr<short>(r)[c] = short((c * 41 + r * 53) % 701 - 350);
            y.ptr<short>(r)[c] = short((c * 17 - r * 29) % 501);
        }
        const cv::Mat before_x = x.clone(), before_y = y.clone();
        Mat dx(x), dy(y), out(cv::Mat(2, 2, CV_8U, cv::Scalar(19)));
        const cv::Mat old = *out.value;
        require(opencv_imgproc_canny_derivatives(dx.handle, dy.handle, out.handle,
                    50, 150, norm) == OPENCV_IMGPROC_OK, "gradient Canny");
        cv::Mat expected;
        cv::Canny(x, y, expected, 50, 150, norm != 0);
        equal(*out.value, expected);
        equal(x, before_x); equal(y, before_y);
        require(old.at<uchar>(0, 0) == 19, "old destination preserved");
        require(opencv_imgproc_canny_derivatives(dx.handle, dy.handle, dx.handle,
                    50, 150, norm) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "self derivative alias");
        Mat alias(x);
        require(opencv_imgproc_canny_derivatives(dx.handle, dy.handle, alias.handle,
                    50, 150, norm) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "shared derivative alias");
        ++canny_cases;
    }
    Mat x(cv::Mat(3, 3, CV_16S, cv::Scalar(0))),
        y(cv::Mat(3, 3, CV_16S, cv::Scalar(0))),
        d(cv::Mat(1, 1, CV_8U, cv::Scalar(23)));
    const auto reject = [&](double low, double high, int norm) {
        require(opencv_imgproc_canny_derivatives(x.handle, y.handle, d.handle,
                    low, high, norm) == OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT,
                "malformed Canny ABI rejected");
        require(d.value->rows == 1 && d.value->at<uchar>(0, 0) == 23,
                "Canny rejection atomicity");
    };
    reject(0, 1, 99);
    reject(-1, 1, 0);
    reject(0, std::numeric_limits<double>::infinity(), 0);
    reject(std::numeric_limits<double>::quiet_NaN(), 1, 0);
    reject(0, double(INT_MAX) + 1, 0);
    reject(0, std::numeric_limits<double>::max(), 1);
    {
        Mat bad(cv::Mat(2, 3, CV_16S, cv::Scalar(0)));
        require(opencv_imgproc_canny_derivatives(x.handle, bad.handle, d.handle,
                    0, 1, 0) == 4, "raw mismatched Canny geometry");
        *bad.value = cv::Mat(3, 3, CV_32F, cv::Scalar(0));
        require(opencv_imgproc_canny_derivatives(bad.handle, y.handle, d.handle,
                    0, 1, 0) == 4, "raw unsupported Canny depth");
        *bad.value = cv::Mat();
        require(opencv_imgproc_canny_derivatives(bad.handle, y.handle, d.handle,
                    0, 1, 0) == 4, "raw empty Canny derivative");
    }
    x.value->setTo(32767); y.value->setTo(32767);
    reject(0, 1, 0); reject(0, 1, 1);
    x.value->setTo(-32768); y.value->setTo(-32768);
    reject(0, 1, 1);
    x.value->setTo(0); y.value->setTo(0);
    require(opencv_imgproc_canny_derivatives(nullptr, y.handle, d.handle, 0, 1, 0) == 4,
            "null Canny input");
    require(opencv_imgproc_canny_derivatives(x.handle, y.handle, nullptr, 0, 1, 0) == 4,
            "null Canny output");
    require(opencv_imgproc_canny_derivatives(x.handle, y.handle, d.handle, 0, 1, 0) == 0,
            "Canny recovery");
    require(!opencv_imgproc_detail::canny_layout(INT_MAX, 1, 1) &&
            !opencv_imgproc_detail::canny_layout(1, INT_MAX, 3) &&
            !opencv_imgproc_detail::canny_layout(50000, 50000, 1),
            "allocation-free Canny arithmetic boundaries");
}
void boxes() {
    for (int sdepth : {CV_8U, CV_16U, CV_16S, CV_32F, CV_64F})
    for (int selector : {0, 1, 2, 3}) {
        if (selector == 1 && sdepth != CV_8U && sdepth != CV_16S) continue;
        const int ddepth = selector == 0 ? sdepth : selector == 1 ? CV_16S :
            selector == 2 ? CV_32F : CV_64F;
        for (int cn : {1, 3, 4}) for (int norm : {0, 1})
        for (int border : {0, 1, 2, 4}) for (int rows : {1, 4})
        for (int cols : {1, 7, 33}) for (cv::Size kernel : {cv::Size(1, 1),
            cv::Size(2, 4), cv::Size(3, 3), cv::Size(5, 5), cv::Size(6, 7)})
        for (bool offcenter : {false, true}) {
            cv::Mat backing(rows + 2, cols + 5, CV_MAKETYPE(sdepth, cn),
                            cv::Scalar::all(97));
            cv::Mat src = backing(cv::Rect(1, 1, cols, rows));
            cv::Mat values(rows, cols, CV_MAKETYPE(CV_64F, cn));
            for (int r = 0; r < rows; ++r) for (int c = 0; c < cols * cn; ++c)
                values.ptr<double>(r)[c] = (r * 17 + c * 3) % 29;
            values.convertTo(src, sdepth);
            const cv::Mat before = src.clone();
            const cv::Point anchor = offcenter ? cv::Point(0, kernel.height - 1) :
                cv::Point(kernel.width / 2, kernel.height / 2);
            Mat input(src), output(src); // distinct headers sharing allocation
            const int abi_border = border == 4 ? 3 : border;
            const auto status = opencv_imgproc_box_filter(input.handle, output.handle,
                kernel.width, kernel.height, selector, anchor.x, anchor.y, norm, abi_border);
            if (status != 0) throw std::runtime_error(opencv_imgproc_last_error_message());
            cv::Mat reference;
            cv::Size effective = kernel;
            cv::Point effective_anchor = anchor;
            if (norm && border != 0) {
                if (cols == 1) { effective.width = 1; effective_anchor.x = 0; }
                if (rows == 1) { effective.height = 1; effective_anchor.y = 0; }
            }
            cv::boxFilter(before, reference, ddepth, effective, effective_anchor, norm != 0,
                          border);
            // Native normalized UInt8 fixed-point rounding can differ by 1;
            // 5.0 BlockSum vs earlier rolling sums can differ in float rounding.
            equal(*output.value, reference, norm && ddepth == CV_8U ? 1 :
                  ddepth == CV_32F ? 1e-4 : 1e-10);
            equal(src, before);
            require(output.value->data != src.data && !output.value->isSubmatrix(),
                    "fresh box output ownership");
            ++box_cases;
        }
    }
    Mat src(cv::Mat(3, 3, CV_8U, cv::Scalar(255))),
        dst(cv::Mat(1, 1, CV_8U, cv::Scalar(29)));
    const auto reject = [&](int w, int h, int depth, int ax, int ay, int norm, int border) {
        require(opencv_imgproc_box_filter(src.handle, dst.handle, w, h, depth,
                    ax, ay, norm, border) == 4, "malformed box ABI rejected");
        require(dst.value->rows == 1 && dst.value->at<uchar>(0, 0) == 29,
                "box rejection atomicity");
    };
    reject(0, 3, 0, 0, 0, 0, 1); reject(-1, 3, 0, 0, 0, 0, 1);
    reject(3, 0, 0, 0, 0, 0, 1); reject(3, -1, 0, 0, 0, 0, 1);
    reject(INT_MAX, INT_MAX, 0, 0, 0, 0, 1);
    reject(3, 3, 99, 0, 0, 0, 1); reject(3, 3, 0, -1, 0, 0, 1);
    reject(3, 3, 0, 3, 0, 0, 1); reject(3, 3, 0, 0, 3, 0, 1);
    reject(3, 3, 0, 0, 0, 2, 1); reject(3, 3, 0, 0, 0, 0, 99);
    reject(3, 3, 0, 0, 0, 0, 4); // module Wrap selector
    {
        Mat invalid;
        require(opencv_imgproc_box_filter(invalid.handle, dst.handle,
                    3, 3, 0, 1, 1, 1, 1) == 4, "raw empty box input");
        *invalid.value = cv::Mat(3, 3, CV_32S, cv::Scalar(0));
        require(opencv_imgproc_box_filter(invalid.handle, dst.handle,
                    3, 3, 0, 1, 1, 1, 1) == 4, "raw unsafe Int32 accumulator");
        const int dimensions[] = {2, 2, 2};
        *invalid.value = cv::Mat(3, dimensions, CV_8U, cv::Scalar(0));
        require(opencv_imgproc_box_filter(invalid.handle, dst.handle,
                    3, 3, 0, 1, 1, 1, 1) == 4, "raw 3-D box input");
    }
    require(opencv_imgproc_box_filter(nullptr, dst.handle, 3, 3, 0, 1, 1, 1, 1) == 4,
            "null box input");
    require(opencv_imgproc_box_filter(src.handle, nullptr, 3, 3, 0, 1, 1, 1, 1) == 4,
            "null box output");
    require(opencv_imgproc_box_filter(src.handle, dst.handle, 3, 3, 0, 1, 1, 0, 1) == 0,
            "box recovery");
    require(dst.value->at<uchar>(0, 0) == 255, "integer saturation");
}
}
int main() {
    try {
        require(cv::getVersionString() == CV_VERSION, "header/runtime version identity");
        canny(); boxes();
        std::cout << CV_VERSION << ": " << canny_cases << " Canny and " << box_cases
                  << " box native-reference cases; malformed ABI/ownership PASS\n";
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n'; return 1;
    }
}