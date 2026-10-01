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
if [ -z "$include_dir" ] || [ ! -d "$include_dir" ] || [ ! -f "$compiler" ]; then
    echo "error: MSYS2 OpenCV headers or matching MinGW g++ not found" >&2
    exit 1
fi

mkdir -p obj/test_support

# Match the validated external production shim compile: native MinGW paths
# and a clean compiler environment, rather than GNAT's header search path.
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
    -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
    "$compiler" -c -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    "-I$(cygpath -m "$include_dir")" \
    "-I$(cygpath -m "$core_prefix/cpp")" \
    -o "$(cygpath -m obj/test_support/watershed_overlap_fixture.o)" \
    "$(cygpath -m cpp/watershed_overlap_fixture.cpp)"