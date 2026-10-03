#!/bin/sh
set -eu

# Run from the Imgproc root after Core is built. Keep test-only compilation
# and the historical version selection outside production projects.
package=
for candidate in opencv5 opencv4 opencv; do
    if pkg-config --exists "$candidate"; then
        package=$candidate
        break
    fi
done
test -n "$package"
core=${OPENCV_CORE_TEST_PREFIX:-../core}
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then
    include=$(pkg-config --variable=includedir_new "$package")
fi
cxx=${CXX:-c++}
mkdir -p tests/bin
for mode in installed legacy; do
    define=
    if [ "$mode" = legacy ]; then
        define=-DOPENCV_IMGPROC_TEST_LEGACY_BAYER_GRAY
    fi
    # pkg-config flags are intentionally word-split. Mark upstream headers
    # as system headers; all project C++ remains strict warnings-as-errors.
    "$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $define \
        $(pkg-config --cflags "$package") -isystem "$include" \
        -I"$core/cpp" tests/bayer_gray_runtime_test.cpp \
        -L"$core/lib" -lopencv_core_shim \
        $(pkg-config --libs-only-L "$package") -lopencv_imgproc -lopencv_core \
        -Wl,-rpath,"$(cd "$core/lib" && pwd)" \
        -o "tests/bin/bayer_gray_$mode"
    "tests/bin/bayer_gray_$mode"
done