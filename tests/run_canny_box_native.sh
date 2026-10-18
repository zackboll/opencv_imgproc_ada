#!/bin/sh
# Run from the repository root. Native/sanitizer dependencies stay test-owned.
set -eu
core=${OPENCV_CORE_TEST_PREFIX:-../core}
package=${OPENCV_TEST_PACKAGE:-opencv4}
cxx=${CXX:-c++}
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then include=$(pkg-config --variable=includedir_new "$package"); fi
library=$(pkg-config --variable=libdir "$package")
version=$(pkg-config --modversion "$package")
mkdir -p tests/bin
binary="tests/bin/canny-box-$version-${SANITIZE:-0}"
sanitize=
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined,float-cast-overflow -fno-omit-frame-pointer -g"
fi
# Set PKG_CONFIG_PATH to an instrumented OpenCV installation to instrument the
# native library as well. The command itself instruments both production shims.
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -I"$core/cpp" tests/canny_box_runtime_test.cpp \
    "$core/cpp/opencv_core_shim.cpp" -L"$library" -Wl,-rpath,"$library" \
    -lopencv_imgproc -lopencv_core -o "$binary"
LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$binary"