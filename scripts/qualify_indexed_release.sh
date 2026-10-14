#!/bin/sh
# Run in a fresh source export, with native OpenCV and the selected Alire tools.
# This deliberately does not accept a Core source override or dependency pin.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
mkdir -p obj/release-qualification
logs="$root/obj/release-qualification"
alr --version
pkg-config --modversion "${OPENCV_TEST_PACKAGE:-opencv4}"
alr -n index --update-all
alr -n settings --set dependencies.shared false
alr -n update
alr -n with --solve > "$logs/resolution.log"
cat "$logs/resolution.log"
if grep -F 'Dependencies (missing):' "$logs/resolution.log"; then
    echo 'error: incomplete indexed dependency solution' >&2
    exit 1
fi
grep -F 'opencv_core=0.4.1 (origin: git)' "$logs/resolution.log"
if grep -E '\[\[pins\]\]|path[[:space:]]*=' alire.toml; then
    echo 'error: release library must not contain development pins' >&2
    exit 1
fi
alr -n build > "$logs/root-build.log" 2>&1
core=$(alr exec -- printenv OPENCV_CORE_ALIRE_PREFIX)
test -f "$core/cpp/opencv_core_module_bridge.hpp"
alr exec -- sh -c 'gnat --version; gprbuild --version; gcc -print-file-name=adalib' > "$logs/toolchain.log"
alr -n -C tests settings --set dependencies.shared false
alr -n -C tests run > "$logs/aunit.log" 2>&1
tail -5 "$logs/aunit.log"
grep -E '^Successful Tests:[[:space:]]+1130$' "$logs/aunit.log"
grep -E '^Failed Assertions:[[:space:]]+0$' "$logs/aunit.log"
grep -E '^Unexpected Errors:[[:space:]]+0$' "$logs/aunit.log"
for name in emd_signature_index bayer_layout morphology_expansion yuv420_layout \
    yuv422_layout resize_exact_layout colormap_layout flood_fill_int32 \
    blend_linear_layout guil_layout squared_box_layout; do
    c++ -std=c++17 -Wall -Wextra -Wpedantic -Werror \
        "tests/${name}_test.cpp" -o "$logs/$name"
    "$logs/$name" > "$logs/$name.log" 2>&1
done
package=${OPENCV_TEST_PACKAGE:-opencv4}
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then
    include=$(pkg-config --variable=includedir_new "$package")
fi
c++ -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer -g \
    -isystem "$include" tests/subpixel_patch_guard_test.cpp \
    $(pkg-config --libs-only-L "$package") -lopencv_core \
    -o "$logs/subpixel_patch_guard"
"$logs/subpixel_patch_guard" > "$logs/subpixel_patch_guard.log" 2>&1
c++ -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer -g \
    -isystem "$include" tests/opencv41_reference.cpp \
    $(pkg-config --libs-only-L "$package") -lopencv_imgproc -lopencv_core \
    -o "$logs/opencv41_reference"
"$logs/opencv41_reference" > "$logs/opencv41_reference.log" 2>&1
export OPENCV_CORE_TEST_PREFIX="$core"
for name in subpixel_patch_native spatial_gradient_native squared_box_consistency \
    ballard_consistency guil_consistency masked_template_consistency \
    masked_ncc_consistency masked_ccorr_consistency masked_nsqdiff_consistency \
    masked_ccoeff_consistency; do
    SANITIZE=1 sh "tests/run_$name.sh" > "$logs/$name.log" 2>&1
done
sh tests/run_bayer_gray_test.sh > "$logs/bayer_gray.log" 2>&1
ldd -r tests/bin/tests > "$logs/aunit-loader.log" 2>&1
readelf -h -d -Ws tests/bin/tests > "$logs/aunit-elf.log"
if grep -E 'not found|undefined symbol' "$logs/aunit-loader.log"; then
    exit 1
fi
echo 'Indexed Core release, full AUnit and native boundary regressions PASS'