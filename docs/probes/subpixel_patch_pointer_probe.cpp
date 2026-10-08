// Recovered Task 043 research findings, originating in commit
// 6ff289919c864372d0ac325b7205624af83a6bc2. Integer offsets only:
// do not form the historical invalid pointers to demonstrate their invalidity.
#include <cassert>
#include <cstdint>
#include <iostream>

int main() {
    for (int channels : {1, 3}) {
        for (int bytes : {1, 4}) {
            const int64_t pixel = channels * bytes;
            const int64_t step = 4 * pixel;
            // adjustRect returns src - rect.x*pixel with rect.x == 1.
            const int64_t top_left = -pixel;
            assert(top_left < 0);
            // Bottom-right src is last pixel; src2 is formed before clamp.
            const int64_t bottom_right_src2 = 3 * step + 3 * pixel + step;
            assert(bottom_right_src2 > 4 * step);
        }
    }
    std::cout << "8 historical offset checks passed (not native execution)\n";
}