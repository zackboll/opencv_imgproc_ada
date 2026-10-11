// The same corpus calls the real production Imgproc and Core shims.
#include "../cpp/opencv_imgproc_shim.cpp"
#include "opencv_core_shim.h"
#include <iostream>
#include <iomanip>
#include <stdexcept>
#include <tuple>

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
cv::Mat shape(int contrast = 255, bool rectangle = false) {
    cv::Mat m(31, 29, CV_8UC1, cv::Scalar(0));
    cv::rectangle(m, cv::Rect(5, 6, 17, 18), cv::Scalar(contrast), -1);
    if (!rectangle) {
        cv::rectangle(m, cv::Rect(13, 6, 9, 9), cv::Scalar(0), -1);
        m.at<uchar>(22, 6) = 0;
    }
    return m;
}
void paste(const cv::Mat &t, cv::Mat &s, int x, int y) {
    for (int r = 0; r < t.rows; ++r)
        for (int c = 0; c < t.cols; ++c)
            if (r+y >= 0 && r+y < s.rows && c+x >= 0 && c+x < s.cols)
                s.at<uchar>(r+y, c+x) = t.at<uchar>(r,c);
}
using Detection = std::tuple<float, float, int>;
std::vector<Detection> run(const std::string &id, const cv::Mat &t,
    const cv::Mat &s, int low = 50, int high = 100, int threshold = 20) {
    Mat templ(t), scene(s), positions(cv::Mat{}), votes(cv::Mat{});
    const cv::Mat before_t = t.clone(), before_s = s.clone();
    require(opencv_imgproc_ballard_detect(templ.handle, scene.handle,
        low, high, threshold, positions.handle, votes.handle) == OPENCV_IMGPROC_OK,
        opencv_imgproc_last_error_message());
    require(cv::norm(t, before_t, cv::NORM_INF) == 0 &&
            cv::norm(s, before_s, cv::NORM_INF) == 0, "input mutation");
    std::vector<Detection> out;
    if (!positions.value->empty()) {
        require(positions.value->cols == votes.value->cols, "counts");
        for (int i = 0; i < positions.value->cols; ++i) {
            const auto p = positions.value->at<cv::Vec4f>(0,i);
            const auto v = votes.value->at<cv::Vec3i>(0,i);
            require(p[2] == 1 && p[3] == 0 && v[0] > threshold, "decode");
            out.emplace_back(p[0], p[1], v[0]);
        }
    } else require(votes.value->empty(), "empty votes");
    std::sort(out.begin(), out.end());
    std::cout << "CASE " << id << ' ' << t.rows << ' ' << t.cols << ' '
        << s.rows << ' ' << s.cols << ' ' << low << ' ' << high << ' '
        << threshold << ' ' << out.size() << '\n';
    for (const auto &d : out)
        std::cout << "MATCH " << std::get<0>(d) << ' ' << std::get<1>(d)
            << ' ' << std::get<2>(d) << '\n';
    return out;
}
void boundaries() {
    using opencv_imgproc_ballard::fits;
    require(fits(31,29,2160,3840), "ordinary 4K scene rejected");
    require(!fits(31,29,INT_MAX,29), "histogram overflow");
    require(!fits(31,INT_MAX,64,64), "template preprocessing overflow");
    require(!fits(31,29,32768,32768), "output byte narrowing");
    require(fits(31,29,16384,16383), "near output boundary accepted");
    require(!fits(31,29,16384,16384), "exact output boundary rejected");
    require(!fits(0,29,64,64), "zero geometry");
    Mat t(shape()), s(shape()), p(cv::Mat(2,2,CV_8UC1,cv::Scalar(77))),
        v(cv::Mat(2,2,CV_8UC1,cv::Scalar(88)));
    const auto reject = [&](const opencv_core_mat_handle *input,
                            int low, int high, int threshold,
                            opencv_core_mat_handle *po,
                            opencv_core_mat_handle *vo) {
        require(opencv_imgproc_ballard_detect(input,s.handle,low,high,threshold,
            po,vo) != OPENCV_IMGPROC_OK, "raw rejection");
        require(p.value->at<uchar>(0,0) == 77 &&
                v.value->at<uchar>(0,0) == 88, "failure atomicity");
    };
    reject(nullptr,50,100,20,p.handle,v.handle);
    reject(t.handle,50,100,20,nullptr,v.handle);
    reject(t.handle,50,100,20,p.handle,p.handle);
    reject(t.handle,50,100,20,t.handle,v.handle);
    reject(t.handle,100,50,20,p.handle,v.handle);
    reject(t.handle,0,100,20,p.handle,v.handle);
    reject(t.handle,50,100,0,p.handle,v.handle);
    Mat wrong(cv::Mat(2,2,CV_32FC1));
    reject(wrong.handle,50,100,20,p.handle,v.handle);
    Mat channels(cv::Mat(2,2,CV_8UC3));
    reject(channels.handle,50,100,20,p.handle,v.handle);
    const int dims[] = {2,2,2};
    Mat nd(cv::Mat(3,dims,CV_8UC1));
    reject(nd.handle,50,100,20,p.handle,v.handle);
    // Forged *native header geometry* on an otherwise valid Core handle;
    // no dangling opaque pointers or fake allocations are dereferenced.
    const int rows = t.value->rows;
    t.value->rows = INT_MAX;
    reject(t.handle,50,100,20,p.handle,v.handle);
    t.value->rows = rows;
    require(opencv_imgproc_ballard_detect(t.handle,s.handle,50,100,20,
        p.handle,v.handle) == OPENCV_IMGPROC_OK, "recovery");
    // Complete reachable finite gradient domain: baseline scalar angle and
    // rounding must index the 361-bin table, including angles rounded to 360.
    bool endpoint = false;
    for (int y = -1020; y <= 1020; ++y)
        for (int x = -1020; x <= 1020; ++x) {
            const float angle = cv::fastAtan2(float(y),float(x));
            const int bin = cvRound(double(angle));
            require(std::isfinite(angle) && bin >= 0 && bin <= 360,
                    "orientation bin");
            endpoint = endpoint || bin == 360;
        }
    require(endpoint, "360 endpoint not exercised");
}
}
int main() {
    try {
        require(cv::getVersionString() == CV_VERSION, "header/runtime mismatch");
        std::cout << std::setprecision(9) << "VERSION " << CV_VERSION << '\n';
        boundaries();
        const cv::Mat t = shape();
        cv::Mat scene(99,111,CV_8UC1,cv::Scalar(0));
        paste(t,scene,37,28);
        const auto baseline = run("asymmetric",t,scene);
        const auto known = std::find_if(baseline.begin(),baseline.end(),
            [](const Detection &d) { return std::get<0>(d) == 51 &&
                                           std::get<1>(d) == 43; });
        require(known != baseline.end(), "known translated center absent");
        const int count = std::get<2>(*known);
        run("strict-below",t,scene,50,100,count-1);
        const auto equal = run("strict-equal",t,scene,50,100,count);
        require(std::find(equal.begin(),equal.end(),*known) == equal.end(),
                "strict threshold");
        run("blank-template",cv::Mat::zeros(t.size(),CV_8UC1),scene);
        run("blank-scene",t,cv::Mat::zeros(scene.size(),CV_8UC1));
        run("identical",t,t);
        run("canny-low",t,scene,10,30);
        run("canny-high",t,scene,100,200);
        run("no-match",t,scene,50,100,10000);
        cv::Mat multiple(140,180,CV_8UC1,cv::Scalar(0));
        paste(t,multiple,12,17); paste(t,multiple,111,85);
        const auto copies = run("multiple",t,multiple);
        require(std::find_if(copies.begin(),copies.end(),[](const Detection &d) {
            return std::get<0>(d)==26 && std::get<1>(d)==32;
        }) != copies.end(), "first copy");
        require(std::find_if(copies.begin(),copies.end(),[](const Detection &d) {
            return std::get<0>(d)==125 && std::get<1>(d)==100;
        }) != copies.end(), "second copy");
        cv::rectangle(multiple,cv::Rect(60,60,30,20),cv::Scalar(255),-1);
        run("distractors",t,multiple);
        const cv::Mat rectangle = shape(255,true);
        cv::Mat rect_scene = cv::Mat::zeros(scene.size(),CV_8UC1);
        paste(rectangle,rect_scene,37,28);
        run("rectangle",rectangle,rect_scene);
        for (int edge = 0; edge < 5; ++edge) {
            cv::Mat s = cv::Mat::zeros(60,70,CV_8UC1);
            const int x[] = {-5, -5, 48, 20, 20};
            const int y[] = {-6, 20, 20, -6, 36};
            paste(t,s,x[edge],y[edge]);
            run("edge-"+std::to_string(edge),t,s,50,100,5);
        }
        for (int edge = 0; edge < 4; ++edge) {
            cv::Mat touching = t.clone();
            if (edge == 0) cv::rectangle(touching,cv::Rect(0,10,8,10),255,-1);
            if (edge == 1) cv::rectangle(touching,cv::Rect(21,10,8,10),255,-1);
            if (edge == 2) cv::rectangle(touching,cv::Rect(7,0,10,8),255,-1);
            if (edge == 3) cv::rectangle(touching,cv::Rect(7,23,10,8),255,-1);
            cv::Mat s = cv::Mat::zeros(scene.size(),CV_8UC1);
            paste(touching,s,37,28);
            run("template-edge-"+std::to_string(edge),touching,s,50,100,5);
        }
        for (int contrast : {5,30,255}) {
            const cv::Mat low = shape(contrast);
            cv::Mat s = cv::Mat::zeros(scene.size(),CV_8UC1);
            paste(low,s,37,28);
            run("contrast-"+std::to_string(contrast),low,s,10,30,5);
        }
        cv::Mat tp(40,40,CV_8UC1,cv::Scalar(197));
        cv::Mat sp(120,130,CV_8UC1,cv::Scalar(213));
        cv::Mat tr = tp(cv::Rect(3,4,t.cols,t.rows)); t.copyTo(tr);
        cv::Mat sr = sp(cv::Rect(4,5,scene.cols,scene.rows)); scene.copyTo(sr);
        require(!tr.isContinuous() && !sr.isContinuous(), "Region fixture");
        require(run("template-region",tr,scene)==baseline, "template isolation");
        require(run("scene-region",t,sr)==baseline, "scene isolation");
        require(run("both-regions",tr,sr)==baseline, "both isolation");
        for (int h : {1,2,3,4,7}) for (int w : {1,2,3,4,7}) {
            cv::Mat small(h,w,CV_8UC1,cv::Scalar(0));
            small.at<uchar>(h/2,w/2)=255;
            run("small-"+std::to_string(h)+"-"+std::to_string(w),small,small,1,2,1);
        }
        cv::Mat large(4096,4096,CV_8UC1,cv::Scalar(0));
        paste(t,large,1200,1100);
        std::cerr << "native threads=" << cv::getNumThreads()
            << "; large fixture pixels=" << large.total()
            << "; tiled size/thread gate="
            << (cv::getNumThreads() > 1 && large.total() >=
                std::max(size_t(1024)*1024,
                    size_t(cv::getNumThreads())*64*1024)) << '\n';
        run("large-preprocessing",t,large);
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n'; return 1;
    }
}