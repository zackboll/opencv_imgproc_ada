#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

int main() {
    cv::Mat source(8, 8, CV_8UC1, cv::Scalar(17));
    cv::Mat destination;
    cv::GaussianBlur(source, destination, cv::Size(3, 3), 0);
    return cv::countNonZero(destination) == 64 ? 0 : 1;
}