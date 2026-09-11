#!/bin/sh

set -eu

shim_build=${1:-}

case "$shim_build" in
    Static_PIC|Relocatable)
        exit 0
        ;;
    External_Relocatable)
        ;;
    *)
        echo "error: unsupported or missing shim build capability: ${shim_build:-<missing>}" >&2
        exit 1
        ;;
esac

if [ "$#" -ne 7 ]; then
    echo "usage: $0 External_Relocatable CXX_DRIVER INCLUDE_DIR LIBRARY_DIR OPENCV_IMGPROC_IMPORT_LIBRARY OPENCV_CORE_IMPORT_LIBRARY CORE_SHIM_IMPORT_LIBRARY" >&2
    exit 1
fi

cxx_driver=$2
include_dir=$3
library_dir=$4
opencv_imgproc_import_library=$5
opencv_core_import_library=$6
core_shim_import_library=$7
source=cpp/opencv_imgproc_shim.cpp
object=obj/shim/external/opencv_imgproc_shim.o
shim_dll=lib/libopencv_imgproc_shim.dll
shim_import_library=lib/libopencv_imgproc_shim.dll.a
core_bridge_include=$(dirname "$(dirname "$core_shim_import_library")")/cpp

mkdir -p lib obj/shim/external
rm -f "$shim_dll" "$shim_import_library" "$object"

case "$cxx_driver" in
    *gnat_native*)
        echo "error: external C++ driver resolved to the GNAT toolchain: $cxx_driver" >&2
        exit 1
        ;;
esac

for required in "$cxx_driver" "$source" "$include_dir" "$library_dir" \
                "$opencv_imgproc_import_library" \
                "$opencv_core_import_library" \
                "$core_shim_import_library" "$core_bridge_include"
do
    if [ ! -e "$required" ]; then
        echo "error: required Imgproc shim build input is missing: $required" >&2
        exit 1
    fi
done

compile_include=$include_dir
compile_bridge_include=$core_bridge_include
compile_source=$source
compile_object=$object
link_object=$object
link_dll=$shim_dll
link_import_library=$shim_import_library
link_opencv_imgproc=$opencv_imgproc_import_library
link_opencv_core=$opencv_core_import_library
link_core_shim=$core_shim_import_library

# Native MinGW g++.exe accepts MSYS paths inconsistently. Preserve the path
# conversion used by the validated Core Windows shim build.
if command -v cygpath >/dev/null 2>&1; then
    compile_include=$(cygpath -m "$include_dir")
    compile_bridge_include=$(cygpath -m "$core_bridge_include")
    compile_source=$(cygpath -m "$source")
    compile_object=$(cygpath -m "$object")
    link_object=$compile_object
    link_dll=$(cygpath -m "$shim_dll")
    link_import_library=$(cygpath -m "$shim_import_library")
    link_opencv_imgproc=$(cygpath -m "$opencv_imgproc_import_library")
    link_opencv_core=$(cygpath -m "$opencv_core_import_library")
    link_core_shim=$(cygpath -m "$core_shim_import_library")
fi

echo "Building External_Relocatable OpenCV Imgproc shim"
echo "C++ driver: $cxx_driver"
echo "OpenCV include: $include_dir"
echo "OpenCV Imgproc import library: $opencv_imgproc_import_library"
echo "OpenCV Core import library: $opencv_core_import_library"
echo "Core shim import library: $core_shim_import_library"

env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
    -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
    "$cxx_driver" -c -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    "-I$compile_include" "-I$compile_bridge_include" \
    -o "$compile_object" "$compile_source"

env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
    -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
    "$cxx_driver" -shared -o "$link_dll" \
    "-Wl,--out-implib,$link_import_library" \
    "$link_object" "$link_opencv_imgproc" "$link_opencv_core" \
    "$link_core_shim"