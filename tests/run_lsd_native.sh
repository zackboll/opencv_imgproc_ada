#!/bin/sh
# Run from repository root, using the same Core/OpenCV as production.
set -eu
core=${OPENCV_CORE_TEST_PREFIX:-../core}
package=${OPENCV_TEST_PACKAGE:-opencv4}
cxx=${CXX:-c++}
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then include=$(pkg-config --variable=includedir_new "$package"); fi
library=$(pkg-config --variable=libdir "$package")
version=$(pkg-config --modversion "$package")
mkdir -p tests/bin
binary="tests/bin/lsd-$version-${SANITIZE:-0}"
sanitize=
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined,float-cast-overflow -fno-omit-frame-pointer -g"
fi
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -I"$core/cpp" tests/lsd_runtime_test.cpp \
    "$core/cpp/opencv_core_shim.cpp" -L"$library" -Wl,-rpath,"$library" \
    -lopencv_imgproc -lopencv_core -o "$binary"
UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
    ASAN_OPTIONS=halt_on_error=1:detect_leaks=1 \
    LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$binary" "$@"