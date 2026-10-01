#!/bin/sh

set -eu

# Only Windows builds this fixture outside GPRbuild. On Linux and macOS the
# test project itself compiles and links the same test-only source.
case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *) exit 0 ;;
esac

core_prefix=${OPENCV_CORE_ALIRE_PREFIX:-}
if [ -z "$core_prefix" ] || [ ! -f "$core_prefix/cpp/opencv_core_module_bridge.hpp" ]; then
    echo "error: indexed Core bridge was not found" >&2
    exit 1
fi

pkg_config=x86_64-w64-mingw32-pkg-config
package=
for candidate in opencv5 opencv4 opencv
do
    if "$pkg_config" --exists "$candidate"; then
        package=$candidate
        break
    fi
done
if [ -z "$package" ]; then
    echo "error: MSYS2 OpenCV pkg-config package not found" >&2
    exit 1
fi

include_dir=$("$pkg_config" --variable=includedir "$package")
if [ -z "$include_dir" ]; then
    include_dir=$("$pkg_config" --variable=includedir_new "$package")
fi
library_dir=$("$pkg_config" --variable=libdir "$package")
compiler="$(dirname "$library_dir")/bin/g++.exe"
opencv_core_import="$library_dir/libopencv_core.dll.a"
core_shim_import="$core_prefix/lib/libopencv_core_shim.dll.a"
if [ -z "$include_dir" ] || [ ! -d "$include_dir" ] ||
   [ ! -f "$compiler" ] || [ ! -f "$opencv_core_import" ] ||
   [ ! -f "$core_shim_import" ]; then
    echo "error: MSYS2 OpenCV headers or matching MinGW g++ not found" >&2
    exit 1
fi
if ! command -v cygpath >/dev/null 2>&1; then
    echo "error: cygpath is required for the MSYS2 MinGW build" >&2
    exit 1
fi

object=obj/test_support/watershed_overlap_fixture.o
dll=bin/libopencv_imgproc_test_support.dll
import_library=obj/test_support/libopencv_imgproc_test_support.dll.a
mkdir -p obj/test_support bin
rm -f "$object" "$dll" "$import_library"

# Match the validated external production shim compile: native MinGW paths
# and a clean compiler environment, rather than GNAT's header search path.
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
    -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
    "$compiler" -c -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    "-I$(cygpath -m "$include_dir")" \
    "-I$(cygpath -m "$core_prefix/cpp")" \
    -o "$(cygpath -m "$object")" \
    "$(cygpath -m cpp/watershed_overlap_fixture.cpp)"

# Link all native C++ and Core dependencies into the test-only DLL, not into
# GNAT's Ada executable. The DLL lives beside tests.exe for Windows loading.
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
    -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
    "$compiler" -shared -o "$(cygpath -m "$dll")" \
    "-Wl,--out-implib,$(cygpath -m "$import_library")" \
    "$(cygpath -m "$object")" \
    "$(cygpath -m "$opencv_core_import")" \
    "$(cygpath -m "$core_shim_import")"