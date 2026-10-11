// The same corpus calls the real production Imgproc and Core shims.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <iomanip>
#include <stdexcept>
#include <tuple>
#include <vector>
#include <algorithm>

namespace {
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
cv::Mat shape() {
    cv::Mat m(48, 40, CV_8UC1, cv::Scalar(0));
    cv::rectangle(m, cv::Rect(6, 7, 27, 3), 255, -1);
    cv::rectangle(m, cv::Rect(31, 8, 3, 15), 255, -1);
    cv::rectangle(m, cv::Rect(14, 22, 19, 3), 255, -1);
    cv::rectangle(m, cv::Rect(14, 25, 3, 14), 255, -1);
    cv::rectangle(m, cv::Rect(6, 20, 9, 3), 255, -1);
    cv::rectangle(m, cv::Rect(8, 10, 5, 5), 255, -1);
    return m;
}
cv::Mat place(const cv::Mat &t, int angle, int num, int den,
              int ox, int oy, int rows, int cols) {
    cv::Mat scene(rows, cols, CV_8UC1, cv::Scalar(0));
    const int cx = t.cols / 2, cy = t.rows / 2;
    int minx = INT_MAX, maxx = INT_MIN, miny = INT_MAX, maxy = INT_MIN;
    auto map = [&](int x, int y, int &rx, int &ry) {
        const int dx = (x - cx) * num, dy = (y - cy) * num;
        if (angle == 0) { rx = dx / den; ry = dy / den; }
        else if (angle == 90) { rx = dy / den; ry = -(dx / den); }
        else { rx = -(dx / den); ry = -(dy / den); }
    };
    for (int y = 0; y < t.rows; ++y)
        for (int x = 0; x < t.cols; ++x)
            if (t.at<uchar>(y, x)) {
                int rx, ry; map(x, y, rx, ry);
                minx = std::min(minx, rx); maxx = std::max(maxx, rx);
                miny = std::min(miny, ry); maxy = std::max(maxy, ry);
            }
    const int sx = ox - (minx + maxx) / 2, sy = oy - (miny + maxy) / 2;
    for (int y = 0; y < t.rows; ++y)
        for (int x = 0; x < t.cols; ++x)
            if (t.at<uchar>(y, x)) {
                int rx, ry; map(x, y, rx, ry);
                const int px = sx + rx, py = sy + ry;
                if (px >= 0 && py >= 0 && px < cols && py < rows)
                    scene.at<uchar>(py, px) = 255;
            }
    return scene;
}
using Detection = std::tuple<float, float, float, float, int, int, int>;
std::vector<Detection> run(const std::string &id, const cv::Mat &t,
    const cv::Mat &s, opencv_imgproc_guil_parameters p) {
    Mat templ(t), scene(s), positions(cv::Mat{}), votes(cv::Mat{});
    const cv::Mat before_t = t.clone(), before_s = s.clone();
    require(opencv_imgproc_guil_detect(templ.handle, scene.handle, &p,
        positions.handle, votes.handle) == OPENCV_IMGPROC_OK,
        opencv_imgproc_last_error_message());
    require(cv::norm(t, before_t, cv::NORM_INF) == 0 &&
            cv::norm(s, before_s, cv::NORM_INF) == 0, "input mutation");
    std::vector<Detection> out;
    if (!positions.value->empty()) {
        require(positions.value->cols == votes.value->cols, "counts");
        for (int i = 0; i < positions.value->cols; ++i) {
            const auto xy = positions.value->at<cv::Vec4f>(0, i);
            const auto v = votes.value->at<cv::Vec3i>(0, i);
            out.emplace_back(xy[0], xy[1], xy[2], xy[3], v[0], v[1], v[2]);
        }
    } else require(votes.value->empty(), "empty votes");
    std::sort(out.begin(), out.end());
    std::cout << std::setprecision(9) << "CASE " << id << ' ' << t.rows << ' '
        << t.cols << ' ' << s.rows << ' ' << s.cols << ' ' << out.size()
        << '\n';
    for (const auto &d : out)
        std::cout << "MATCH " << std::get<0>(d) << ' ' << std::get<1>(d) << ' '
            << std::get<2>(d) << ' ' << std::get<3>(d) << ' ' << std::get<4>(d)
            << ' ' << std::get<5>(d) << ' ' << std::get<6>(d) << '\n';
    return out;
}
opencv_imgproc_guil_parameters params(
    double amin, double amax, double astep, double smin, double smax,
    double sstep, int ath = 50, int sth = 50, int pth = 100) {
    return {amin, amax, astep, smin, smax, sstep, 50, 100, ath, sth, pth};
}
void boundaries() {
    using opencv_imgproc_guil::Parameters;
    using opencv_imgproc_guil::fits;
    const Parameters ordinary{0, 2, 1, 0.98, 1.02, 0.02, 50, 50, 100};
    require(fits(48, 40, 180, 200, ordinary), "ordinary fixture rejected");
    require(!fits(48, 40, INT_MAX, 40, ordinary), "area overflow");
    require(!fits(0, 40, 80, 80, ordinary), "zero geometry");
    const Parameters wide{0, 360, 1, 0.5, 2, 0.05, 1, 1, 1};
    require(!fits(48, 40, 8192, 8192, wide), "broad output bound");
    require(fits(48, 40, 64, 64, wide), "moderate broad search");
    const Parameters bad{10, 2, 1, 0.5, 2, 0.05, 1, 1, 1};
    require(!fits(48, 40, 80, 80, bad), "inverted angle range");
}
} // namespace

int main() {
    try {
        std::cout << "VERSION " << CV_VERSION << '\n';
        boundaries();
        const cv::Mat t = shape();
        const auto narrow = params(0, 2, 1, 0.98, 1.02, 0.02);
        const cv::Mat scene = place(t, 0, 1, 1, 70, 60, 160, 180);
        run("translation", t, scene, narrow);
        run("identical", t, t, narrow);
        run("blank-template", cv::Mat::zeros(t.size(), CV_8UC1), scene, narrow);
        run("blank-scene", t, cv::Mat::zeros(scene.size(), CV_8UC1), narrow);
        run("rotated-90", t, place(t, 90, 1, 1, 70, 60, 180, 200),
            params(89, 91, 1, 0.98, 1.02, 0.02));
        run("rotated-180", t, place(t, 180, 1, 1, 70, 60, 180, 200),
            params(179, 181, 1, 0.98, 1.02, 0.02));
        run("scaled-down", t, place(t, 0, 3, 4, 70, 60, 180, 200),
            params(0, 2, 1, 0.74, 0.76, 0.01, 20, 10, 20));
        run("scaled-up", t, place(t, 0, 5, 4, 90, 80, 240, 260),
            params(0, 2, 1, 1.24, 1.26, 0.01, 20, 10, 20));
        run("combined", t, place(t, 90, 5, 4, 90, 80, 260, 280),
            params(89, 91, 1, 1.24, 1.26, 0.01, 15, 8, 8));
        cv::Mat first = place(t, 0, 1, 1, 40, 35, 180, 220);
        cv::Mat second = place(t, 0, 1, 1, 140, 110, 180, 220);
        cv::max(first, second, first);
        run("multiple", t, first, narrow);
        cv::rectangle(first, cv::Rect(150, 120, 40, 35), 255, -1);
        run("distractor", t, first, narrow);
        run("no-match", t, scene, params(0, 2, 1, 0.98, 1.02, 0.02, 50, 50,
            100000));
        run("broad", t, scene, params(0, 20, 5, 0.8, 1.3, 0.1));
        cv::Mat parent(220, 240, CV_8UC1, cv::Scalar(40));
        scene.copyTo(parent(cv::Rect(9, 8, scene.cols, scene.rows)));
        run("scene-region", t, parent(cv::Rect(9, 8, scene.cols, scene.rows)),
            narrow);
        cv::Mat edge = place(t, 0, 1, 1, 10, 8, 80, 90);
        run("edge-touching", t, edge, params(0, 2, 1, 0.98, 1.02, 0.02, 20, 20,
            20));
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
