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
version=$(pkg-config --modversion "$package")
include=${OPENCV_TEST_INCLUDE:-$include}
extra_include=${OPENCV_TEST_EXTRA_INCLUDE:-$include}
generated_include=${OPENCV_TEST_GENERATED_INCLUDE:-$include}
library=${OPENCV_TEST_LIBRARY:-$(pkg-config --variable=libdir "$package")}
binary="tests/bin/squared_box-${version}-${cxx##*/}-${SANITIZE:-0}"
sanitize=
intercept=
if [ "$(uname -s)" = Linux ]; then
    intercept="-DSQUARED_BOX_INTERCEPT -Wl,--wrap=_ZN2cv12sqrBoxFilterERKNS_11_InputArrayERKNS_12_OutputArrayEiNS_5Size_IiEENS_6Point_IiEEbi"
fi
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined -fno-omit-frame-pointer -g"
fi
# Production Core/Imgproc shims and corpus instrumented when requested;
# preinstalled OpenCV libraries are not instrumented by this command.
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize $intercept \
    -isystem "$include" -isystem "$extra_include" \
    -isystem "$generated_include" -I"$core/cpp" \
    tests/squared_box_consistency.cpp \
    "$core/cpp/opencv_core_shim.cpp" \
    -L"$library" -Wl,-rpath,"$library" -lopencv_imgproc -lopencv_core \
    -o "$binary"
LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$binary" > "${OUTPUT:-tests/bin/squared_box-${version}.txt}"