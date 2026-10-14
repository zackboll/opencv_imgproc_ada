#!/bin/sh
# Test-only native oracle, built with the production OpenCV C++ toolchain.
set -eu
# Dependency pre-build actions have generated the production configuration.
# Do not nest a root Alire environment inside the test crate's sandbox.
configuration=../config/opencv_imgproc_install.gpr
setting() {
    sed -n "s/^[[:space:]]*$1 := \"\(.*\)\";[[:space:]]*$/\1/p" "$configuration"
}
cxx=$(setting Cxx_Driver)
include=$(setting Include_Switch)
library=$(setting Library_Search_Switch)
imgproc=$(setting OpenCV_Imgproc_Link_Option)
opencv_core=$(setting OpenCV_Core_Link_Option)
core=${OPENCV_CORE_ALIRE_PREFIX:?indexed Core must be resolved}
mkdir -p obj/native config
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror -fPIC \
    "$include" "-I$core/cpp" -c native/reference.cpp -o obj/native/reference.o
case $(uname -s) in
    MINGW*|MSYS*)
        mkdir -p ../lib
        "$cxx" -shared obj/native/reference.o "$library" "$imgproc" "$opencv_core" \
            "$(setting Core_Shim_Link_Option)" \
            -Wl,--out-implib,obj/native/libimgproc_test_reference.dll.a \
            -o ../lib/libimgproc_test_reference.dll
        ;;
    *) ar rcs obj/native/libimgproc_test_reference.a obj/native/reference.o ;;
esac