#include "../cpp/subpixel_patch_guard.hpp"
#include <cassert>
#include <iostream>
#include <limits>

int main() {
    using namespace opencv_imgproc_subpixel;
    Guard g;
    assert(plan(4, 4, 1, 1, 1.0f, 1.0f, 1, 1, 1, false, g));
    assert(g.direct);
    assert(plan(4, 4, 3, 3, 0.0f, 0.0f, 1, 1, 1, false, g));
    assert(!g.direct && g.left == 1 && g.top == 1);
    assert(plan(4, 4, 1, 1, 3.0f, 3.0f, 1, 1, 1, false, g));
    assert(g.right == 1 && g.bottom == 1);
    assert(plan(4, 4, 9, 7, 0.0f, 0.0f, 1, 1, 1, false, g));
    assert(!plan(4, 4, 0, 1, 0.0f, 0.0f, 1, 1, 1, false, g));
    assert(!plan(4, 4, 1, 1, std::numeric_limits<float>::infinity(),
                 0.0f, 1, 1, 1, false, g));
    assert(!plan(INT_MAX, 4, INT_MAX, 1, 0.0f, 0.0f,
                 1, 1, 1, false, g));
    assert(!plan(4, 4, INT_MAX / 3 + 1, 1, 0.0f, 0.0f,
                 3, 1, 1, false, g));
    assert(!plan(4, 4, INT_MAX / 4 + 1, 1, 0.0f, 0.0f,
                 1, 1, 4, true, g));
    assert(input_step_safe(1, INT_MAX));
    assert(!input_step_safe(1, size_t(INT_MAX) + 1));
    assert(input_step_safe(3, size_t(INT_MAX) + 1));
    assert(plan(1, 1, INT_MAX - 1, 1, 0, 0, 1, 1, 1, false, g));
    assert(g.columns == INT_MAX && g.x == -1073741824);
    assert(!plan(1, 1, INT_MAX, 1, 0, 0, 1, 1, 1, false, g));
    // Exact C3 neighbour-index boundary, without any allocation.
    assert(plan(INT_MAX / 3, 4, INT_MAX / 3 - 1, 1,
                float(INT_MAX / 6), 1, 3, 1, 1, false, g));
    assert(!plan(INT_MAX / 3, 4, INT_MAX / 3, 1,
                 float(INT_MAX / 6), 1, 3, 1, 1, false, g));
    assert(plan(INT_MAX / 4, 4, INT_MAX / 4, 1,
                float(INT_MAX / 8), 1, 1, 1, 4, true, g));
    assert(!plan(INT_MAX, 4, INT_MAX / 4 + 1, 1,
                 float(INT_MAX / 8), 1, 1, 1, 4, true, g));
    assert(plan(INT_MAX, 4, 1, 1, 2147483520.0f, 1,
                1, 1, 1, false, g));
    assert(g.x == 2147483520 && g.direct);
    assert(!plan(INT_MAX, 4, 1, 1, 2147483648.0f, 1,
                 1, 1, 1, false, g));
    assert(!plan(INT_MAX, 4, INT_MAX, 1, 2147483520.0f, 1,
                 1, 1, 4, true, g));
    assert(!plan(4, 4, -1, 1, 0, 0, 1, 1, 1, false, g));
    assert(!plan(4, INT_MAX, 3, 1, 0, 1, 1, 1, 1, false, g));
    // Only windows crossing both the top and the right border avoid IPP.
    assert(plan(4, 4, 3, 3, 3.0f, 0.0f, 1, 1, 1, false, g));
    assert(requires_portable_sampler(g));
    assert(plan(4, 4, 2, 2, 2.5f, 0.0f, 1, 1, 1, false, g));
    assert(requires_portable_sampler(g));
    assert(plan(4, 4, 1, 4, 3.0f, 0.0f, 1, 1, 1, false, g));
    assert(requires_portable_sampler(g));
    assert(plan(4, 4, 9, 9, 1.5f, 1.5f, 1, 1, 1, false, g));
    assert(requires_portable_sampler(g));
    assert(plan(1, 4, 3, 3, 0.0f, 0.0f, 1, 1, 1, false, g));
    assert(requires_portable_sampler(g));
    assert(plan(4, 4, 3, 3, 0.0f, 0.0f, 1, 1, 1, false, g));
    assert(!requires_portable_sampler(g));
    assert(plan(4, 4, 3, 3, 1.0f, 0.0f, 1, 1, 1, false, g));
    assert(!requires_portable_sampler(g));
    assert(plan(4, 4, 3, 3, 3.0f, 1.0f, 1, 1, 1, false, g));
    assert(!requires_portable_sampler(g));
    assert(plan(4, 4, 3, 3, 3.0f, 3.0f, 1, 1, 1, false, g));
    assert(!requires_portable_sampler(g));
    assert(plan(4, 4, 1, 1, 1.0f, 1.0f, 1, 1, 1, false, g));
    assert(g.direct && !requires_portable_sampler(g));
    // The scope restores the caller's thread-local selection, also on throw.
    for (bool requested : {true, false}) {
        cv::ipp::setUseIPP(requested);
        const bool before = cv::ipp::useIPP();
        {
            const Scoped_Portable_Sampler portable(true);
            assert(!cv::ipp::useIPP());
        }
        assert(cv::ipp::useIPP() == before);
        {
            const Scoped_Portable_Sampler unchanged(false);
            assert(cv::ipp::useIPP() == before);
        }
        try {
            const Scoped_Portable_Sampler portable(true);
            throw 1;
        } catch (int) {
        }
        assert(cv::ipp::useIPP() == before);
    }
    std::cout << "guard arithmetic boundary checks passed\n";
}