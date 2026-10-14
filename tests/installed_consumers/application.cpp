#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>

// Application-owned C++ code; no binding handles or cv::Mat pointers cross ABI.
extern "C" int application_native_check() noexcept {
    try {
        cv::Mat color(6, 8, CV_8UC3, cv::Scalar(90, 90, 90)), gray, blurred;
        cv::cvtColor(color, gray, cv::COLOR_BGR2GRAY);
        cv::GaussianBlur(gray, blurred, cv::Size(3, 3), 1.0);
        std::cout << "Application OpenCV " << CV_VERSION << '\n';
        return blurred.at<unsigned char>(2, 3) == 90 ? 0 : 1;
    } catch (...) {
        return 2;
    }
}