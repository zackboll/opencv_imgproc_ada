#!/bin/sh
set -eu
core=${OPENCV_CORE_TEST_PREFIX:-../core}
package=${OPENCV_TEST_PACKAGE:-opencv4}
cxx=${CXX:-c++}
mkdir -p tests/bin
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then
    include=$(pkg-config --variable=includedir_new "$package")
fi
sanitize=
version=$(pkg-config --modversion "$package")
binary="tests/bin/subpixel_patch_native-${version}-${cxx##*/}-${SANITIZE:-0}"
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined -fno-omit-frame-pointer -g"
fi
# Full production Imgproc/Core shims are instrumented when requested.
# Installed OpenCV shared libraries are NOT instrumented.
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -I"$core/cpp" \
    tests/subpixel_patch_runtime_test.cpp "$core/cpp/opencv_core_shim.cpp" \
    $(pkg-config --libs-only-L "$package") -lopencv_imgproc -lopencv_core \
    -Wl,--wrap=_ZN2cv13getRectSubPixERKNS_11_InputArrayENS_5Size_IiEENS_6Point_IfEERKNS_12_OutputArrayEi \
    -o "$binary"
"$binary"