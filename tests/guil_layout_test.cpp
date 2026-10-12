#include "../cpp/guil_layout_fits.hpp"
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>

namespace {
int failures = 0;
void check(bool condition, const char *message) {
    if (!condition) {
        std::cerr << message << '\n';
        ++failures;
    }
}
int native_count(double minimum, double maximum, double step) {
    return static_cast<int>(std::ceil((maximum - minimum) * (1.0 / step)));
}
int division_count(double minimum, double maximum, double step) {
    return static_cast<int>(std::ceil((maximum - minimum) / step));
}
opencv_imgproc_guil::Parameters make(
    double amin, double amax, double astep, double smin, double smax,
    double sstep) {
    return {amin, amax, astep, smin, smax, sstep, 1, 1, 1};
}
}

int main() {
    using opencv_imgproc_guil::Layout;
    using opencv_imgproc_guil::plan;
    Layout layout{};
    const auto split = make(0.1, 0.8, 0.1, 0.5, 0.6, 0.2);
    check(native_count(0.1, 0.8, 0.1) == 8, "native angle count");
    check(division_count(0.1, 0.8, 0.1) == 7, "division angle count");
    check(native_count(0.5, 0.6, 0.2) == 1, "native scale count");
    check(plan(48, 40, 64, 64, split, layout), "split ranges accepted");
    check(layout.angle_bins == 8 && layout.scale_bins == 1,
          "planned native counts");
    check(!plan(48, 40, 4096, 4096, split, layout),
          "native reciprocal count rejects boundary scene");
    check(plan(48, 40, 4096, 4095, split, layout),
          "adjacent safe boundary is accepted");
    check(layout.angle_bins == 8 && layout.scale_bins == 1,
          "accepted boundary retains native counts");

    const auto wide = make(0.0, 360.0, 1.0, 0.5, 2.0, 0.05);
    check(!plan(48, 40, 4096, 4096, wide, layout), "4096 scene rejected");
    check(plan(48, 40, 4096, 3, wide, layout), "nearby 4096x3 accepted");
    check(layout.angle_bins == 360 && layout.scale_bins == 30,
          "full-search counts");
    check(!plan(48, 40, 4096, 4, wide, layout), "4096x4 exceeds output width");
    constexpr std::int64_t rejected =
        std::int64_t(360) * 30 * 4096 * 4096;
    constexpr std::int64_t accepted =
        std::int64_t(360) * 30 * 4096 * 3;
    check(rejected == 181193932800LL, "documented rejected magnitude");
    check(rejected / 1350 == 134217728LL, "rejected multiple of INT_MAX/16");
    check(rejected > std::numeric_limits<int>::max() / 16, "exceeds width");
    check(accepted <= std::numeric_limits<int>::max() / 16, "nearby fits");

    struct Sample { double minimum, maximum, step; int native, divided; };
    const Sample samples[] = {
        {0.0, 1.0, 0.1, 10, 10},
        {0.1, 0.4, 0.1, 4, 4},
        {0.2, 0.5, 0.1, 3, 3},
        {1.0, 1.4, 0.1, 4, 4},
        {0.05, 0.35, 0.1, 3, 3},
        {0.3, 1.0, 0.3, 3, 3},
        {0.1, 1.0, 0.3, 3, 3},
        {0.1, 0.3, 0.2, 1, 1},
        {0.7, 1.4, 0.7, 1, 1},
    };
    for (const Sample &sample : samples) {
        check(native_count(sample.minimum, sample.maximum, sample.step) ==
                  sample.native, "sample native count");
        check(division_count(sample.minimum, sample.maximum, sample.step) ==
                  sample.divided, "sample division count");
        const auto parameters = make(
            sample.minimum, sample.minimum + sample.step, sample.step,
            sample.minimum, sample.maximum, sample.step);
        if (sample.minimum >= 0.0 && sample.maximum <= 360.0 &&
            sample.step < 360.0 && sample.minimum < sample.maximum) {
            Layout planned{};
            check(plan(8, 8, 8, 8, parameters, planned), "sample plan");
            check(planned.scale_bins == sample.native, "sample planned bins");
        }
    }
    const auto differing = make(0.0, 1.0, 1.0, 0.1, 0.8, 0.1);
    check(plan(8, 8, 8, 8, differing, layout), "differing scale accepted");
    check(layout.angle_bins == 1 && layout.scale_bins == 8,
          "scale uses reciprocal count");
    check(native_count(0.1, 0.8, 0.1) != division_count(0.1, 0.8, 0.1),
          "reciprocal and division disagree");
    if (failures != 0) {
        std::cerr << failures << " Guil layout checks failed\n";
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
