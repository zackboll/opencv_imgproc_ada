#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <cmath>
#include <iostream>

// Independent native probe: physical tiles and original Ada textured fixture.
int main()
{
    std::cout << "VERSION " << CV_VERSION << '\n';
    if (cv::getVersionMajor()!=CV_VERSION_MAJOR ||
        cv::getVersionMinor()!=CV_VERSION_MINOR ||
        cv::getVersionRevision()!=CV_VERSION_REVISION) return 1;
    int failures=0;
    const int codes[3][2][4] = {
        {{46,47,48,49},{48,49,46,47}},
        {{62,63,64,65},{64,65,62,63}},
        {{135,136,137,138},{137,138,135,136}}};
    const int tile[4][2][2] = {
        {{2,1},{1,0}}, {{1,2},{0,1}}, {{0,1},{1,2}}, {{1,0},{2,1}}};
    for (bool optimized : {true,false}) {
    cv::setUseOptimized(optimized);
    std::cout << "OPTIMIZED " << optimized << '\n';
    for (int depth : {CV_8U, CV_16U}) {
        for (int method=0; method<3; ++method) {
            if (depth==CV_16U && method==1) continue;
            for (int pattern=0; pattern<4; ++pattern) {
                for (int textured : {0,1}) {
                    cv::Mat src(32,32,CV_MAKETYPE(depth,1));
                    const int values8[3]={50,100,200};
                    const int values16[3]={10000,30000,50000};
                    for (int y=0;y<32;++y) for (int x=0;x<32;++x) {
                        const int value=textured ?
                            ((x*17+y*31+x*y*7+(x<16?0:83))%240)*(depth==CV_8U?1:251) :
                            (depth==CV_8U?values8:values16)[tile[pattern][y%2][x%2]];
                        if (depth==CV_8U) src.at<unsigned char>(y,x)=static_cast<unsigned char>(value);
                        else src.at<unsigned short>(y,x)=static_cast<unsigned short>(value);
                    }
                    cv::Mat bgr,rgb;
                    const cv::Mat before=src.clone();
                    cv::demosaicing(src,bgr,codes[method][0][pattern]);
                    cv::demosaicing(src,rgb,codes[method][1][pattern]);
                    int interior=0,border=0, maximum=0;
                    for (int y=0;y<32;++y) for (int x=0;x<32;++x) for (int c=0;c<3;++c) {
                        const int a=depth==CV_8U ? bgr.at<cv::Vec3b>(y,x)[c] : bgr.at<cv::Vec<unsigned short,3>>(y,x)[c];
                        const int b=depth==CV_8U ? rgb.at<cv::Vec3b>(y,x)[2-c] : rgb.at<cv::Vec<unsigned short,3>>(y,x)[2-c];
                        if (a!=b) {
                            if (interior+border<4)
                                std::cout << "PIXEL " << y << ' ' << x << ' ' << c << " BGR=" << a << " reversedRGB=" << b << '\n';
                            if (y>=8 && y<24 && x>=8 && x<24) ++interior; else ++border;
                            maximum=std::max(maximum,std::abs(a-b));
                        }
                    }
                    std::cout << "BAYER depth=" << depth << " method=" << method << " pattern=" << pattern
                              << " texture=" << textured << " codes=" << codes[method][0][pattern] << ',' << codes[method][1][pattern]
                              << " interior=" << interior << " outside=" << border << " max=" << maximum << '\n';
                    if (cv::norm(src,before,cv::NORM_INF)!=0) ++failures;
                    if (method==2) {
                        // Exact original fixture: legacy scalar rounding is
                        // asymmetric; modern selectors reverse bit-exactly.
                        if (CV_VERSION_MAJOR==4 && CV_VERSION_MINOR==1) {
                            if (textured && (interior!=16 || border!=16 || maximum!=1)) ++failures;
                            if (!textured && maximum!=0) ++failures;
                        } else if (CV_VERSION_MAJOR>=5 || CV_VERSION_MINOR>=6) {
                            if (maximum!=0) ++failures;
                        }
                    }
                }
            }
        }
    }
    }
    cv::Mat src(2,2,CV_16UC1);
    for (int y=0;y<2;++y) for (int x=0;x<2;++x)
        src.at<unsigned short>(y,x)=x==0?1000:50000;
    cv::Mat dst(3,4,CV_16UC1,cv::Scalar(123));
    try {
        const double threshold=cv::threshold(src,dst,0,255,cv::THRESH_OTSU|cv::THRESH_TOZERO);
        std::cout << "OTSU success threshold=" << threshold << " finite=" << std::isfinite(threshold) << '\n';
        if ((CV_VERSION_MAJOR==4 && CV_VERSION_MINOR<4) || !std::isfinite(threshold) || threshold!=1000) ++failures;
    } catch (const cv::Exception &e) {
        std::cout << "OTSU rejected " << e.what() << " destination=" << dst.rows << 'x' << dst.cols << '\n';
        if (CV_VERSION_MAJOR!=4 || CV_VERSION_MINOR>=4 || dst.rows!=3 || dst.cols!=4 || dst.at<unsigned short>(0,0)!=123) ++failures;
    }
    std::cout << "REFERENCE failures=" << failures << '\n';
    return failures==0 ? 0 : 1;
}