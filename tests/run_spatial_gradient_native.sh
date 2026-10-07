#!/bin/sh
set -eu

# Linux/ELF regression harness: --wrap observes the actual C++ call boundary.
# Run from the Imgproc root. All tool dependencies remain test-owned.
core=${OPENCV_CORE_TEST_PREFIX:-../core}
package=${OPENCV_TEST_PACKAGE:-opencv4}
cxx=${CXX:-c++}
mkdir -p tests/bin
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then
    include=$(pkg-config --variable=includedir_new "$package")
fi
# Optional sanitizers instrument the full production Imgproc shim, this test,
# and the real Core shim. Installed OpenCV libraries are NOT instrumented.
sanitize=
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined -fno-omit-frame-pointer -g"
fi
# Intentional word splitting for compiler/pkg-config switch lists.
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -I"$core/cpp" \
    tests/spatial_gradient_runtime_test.cpp "$core/cpp/opencv_core_shim.cpp" \
    $(pkg-config --libs-only-L "$package") -lopencv_imgproc -lopencv_core \
    -Wl,--wrap=_ZN2cv15spatialGradientERKNS_11_InputArrayERKNS_12_OutputArrayES5_ii \
    -o tests/bin/spatial_gradient_native
tests/bin/spatial_gradient_native