#include "../cpp/squared_box_layout_fits.hpp"

#include <cassert>
#include <climits>
#include <iostream>

int main()
{
    using namespace opencv_imgproc_squared_box;
    Layout layout;
    for (int channels : {1, 3}) {
        assert(plan(2, 2, 0, channels, 33025, 1, 0, 1, layout));
        assert(!plan(2, 2, 0, channels, 33026, 1, 0, 1, layout));
        assert(plan(2, 2, 0, channels, 1, 33025, 0, 1, layout));
        assert(!plan(2, 2, 0, channels, 1, 33026, 0, 1, layout));
        for (int border : {1, 2, 4}) {
            assert(plan(1, 1, 0, channels, INT_MAX, INT_MAX, 1,
                        border, layout));
            assert(layout.kernel_width == 1 && layout.kernel_height == 1);
        }
        assert(!plan(1, 1, 0, channels, 33026, 1, 1, 0, layout));
        assert(!plan(2, 2, 5, channels, INT_MAX, 2, 0, 1, layout));
        assert(!plan(2, 2, 5, channels, 1, INT_MAX, 0, 1, layout));
        assert(!plan(2, INT_MAX, 5, channels, 1, 1, 0, 1, layout));
    }
    assert(plan(1, 1, 5, 1, 2, 4, 1, 0, layout));
    assert(layout.native_width == 2 && layout.native_height == 2);
    assert(layout.parent_width == 3 && layout.parent_height == 6);
    assert(!plan(0, 1, 0, 1, 1, 1, 0, 1, layout));
    assert(!plan(1, 1, 0, 2, 1, 1, 0, 1, layout));
    assert(!plan(1, 1, 0, 1, 1, 1, 2, 1, layout));
    assert(!plan(1, 1, 0, 1, 1, 1, 0, 3, layout));
    // Float32 C1, kh=1: aligned width * 8 * (4-1) <= INT_MAX.
    // 89478464 is the last accepted 64-column-aligned block.
    assert(plan(1, 89478464, 5, 1, 1, 1, 0, 1, layout));
    assert(!plan(1, 89478465, 5, 1, 1, 1, 0, 1, layout));
    // Float32 C3 applies the same bound with 24 buffer bytes per pixel.
    assert(plan(1, 29826112, 5, 3, 1, 1, 0, 1, layout));
    assert(!plan(1, 29826113, 5, 3, 1, 1, 0, 1, layout));
    // kh=1, four output rows per batch: width * channels * 8 * 4.
    assert(plan(4, 67108863, 0, 1, 1, 1, 0, 1, layout));
    assert(!plan(4, 67108864, 0, 1, 1, 1, 0, 1, layout));

    // Compare periodic closed-form mapping with independent repeated folding.
    for (int length = 1; length <= 9; ++length)
        for (int border : {0, 1, 2, 4})
            for (int coordinate = -100; coordinate <= 100; ++coordinate) {
                int expected = coordinate;
                if (expected < 0 || expected >= length) {
                    if (border == 0) expected = -1;
                    else if (border == 1 || length == 1)
                        expected = expected < 0 ? 0 : length - 1;
                    else while (expected < 0 || expected >= length) {
                        if (expected < 0)
                            expected = -expected - (border == 2 ? 1 : 0);
                        else
                            expected = 2 * length - expected -
                                       (border == 2 ? 1 : 2);
                    }
                }
                assert(border_index(coordinate, length, border) == expected);
            }
    std::cout << "Squared-box research layout and border tests passed\n";
}