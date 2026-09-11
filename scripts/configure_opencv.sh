#!/bin/sh

set -eu

output=config/opencv_imgproc_install.gpr
sysname=$(uname -s)

# Prefer the MinGW target-prefixed pkg-config on MSYS2/MinGW Windows.
# The generic "pkg-config" name can resolve to Strawberry Perl's
# pkg-config.bat, which does not see MSYS2 OpenCV metadata.
pkg_config=pkg-config
case "$sysname" in
    MINGW*|MSYS*)
        if command -v x86_64-w64-mingw32-pkg-config >/dev/null 2>&1; then
            pkg_config=x86_64-w64-mingw32-pkg-config
        fi
        ;;
esac

if ! command -v "$pkg_config" >/dev/null 2>&1; then
    echo "error: $pkg_config is required to locate OpenCV Imgproc" >&2
    exit 1
fi

package=
for candidate in opencv5 opencv4 opencv
do
    if "$pkg_config" --exists "$candidate"; then
        package=$candidate
        break
    fi
done

# MacPorts installs opencv4 pkg-config metadata under
# <prefix>/lib/opencv4/pkgconfig rather than the normal
# <prefix>/lib/pkgconfig directory. Only search that location when the
# usual lookup failed; pkg-config remains authoritative afterwards.
if [ -z "$package" ]; then
    if [ "$sysname" = "Darwin" ] && command -v port >/dev/null 2>&1; then
        macports_prefix=$(dirname "$(dirname "$(command -v port)")")
        macports_pkgconfig="${macports_prefix}/lib/opencv4/pkgconfig"
        if [ -d "$macports_pkgconfig" ]; then
            PKG_CONFIG_PATH="${macports_pkgconfig}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
            export PKG_CONFIG_PATH
            for candidate in opencv5 opencv4 opencv
            do
                if "$pkg_config" --exists "$candidate"; then
                    package=$candidate
                    break
                fi
            done
        fi
    fi
fi

if [ -z "$package" ]; then
    echo "error: pkg-config package was not found (tried opencv5, opencv4, opencv)" >&2
    exit 1
fi

include_dir=$("$pkg_config" --variable=includedir "$package")

if [ -z "$include_dir" ]; then
    include_dir=$("$pkg_config" --variable=includedir_new "$package")
fi

library_dir=$("$pkg_config" --variable=libdir "$package")

if [ -z "$include_dir" ] || [ -z "$library_dir" ]; then
    echo "error: '$package' does not define a usable include directory and libdir" >&2
    exit 1
fi

# macOS OpenCV from Homebrew or MacPorts is built with Apple clang++ and
# libc++. The C++ shim must use that same compiler and runtime. Linux
# OpenCV uses g++ and libstdc++, which remains the default.
cxx_runtime_switch="-lstdc++"
cxx_driver="g++"
shim_build="Static_PIC"
cxx_toolchain="GNU"
cxx_sysroot=""
opencv_imgproc_link_option="-lopencv_imgproc"
opencv_core_link_option="-lopencv_core"
core_shim_link_option=""

if [ "$sysname" = "Darwin" ]; then
    shim_build="Relocatable"
    cxx_toolchain="Apple_Clang"
    cxx_runtime_switch="-lc++"
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "error: xcrun is required to locate Apple clang++ and the macOS SDK" >&2
        exit 1
    fi
    cxx_driver=$(xcrun --find clang++)
    if [ -z "$cxx_driver" ]; then
        echo "error: Apple clang++ is required to compile the OpenCV C++ shim on macOS" >&2
        exit 1
    fi
    cxx_sysroot=$(xcrun --sdk macosx --show-sdk-path)
    if [ -z "$cxx_sysroot" ]; then
        echo "error: could not resolve the macOS SDK path via xcrun --sdk macosx --show-sdk-path" >&2
        exit 1
    fi
fi

case "$sysname" in
    MINGW*|MSYS*)
        shim_build="External_Relocatable"
        opencv_imgproc_import_library="${library_dir}/libopencv_imgproc.dll.a"
        opencv_core_import_library="${library_dir}/libopencv_core.dll.a"
        for import_library in \
            "$opencv_imgproc_import_library" "$opencv_core_import_library"
        do
            if [ ! -f "$import_library" ]; then
                echo "error: OpenCV import library was not found: $import_library" >&2
                exit 1
            fi
        done
        opencv_imgproc_link_option=$opencv_imgproc_import_library
        opencv_core_link_option=$opencv_core_import_library

        core_prefix=${OPENCV_CORE_ALIRE_PREFIX:-}
        if [ -z "$core_prefix" ]; then
            echo "error: OPENCV_CORE_ALIRE_PREFIX is required to locate the Core shim" >&2
            exit 1
        fi
        core_shim_link_option="${core_prefix}/lib/libopencv_core_shim.dll.a"
        if [ ! -f "$core_shim_link_option" ]; then
            echo "error: Core shim import library was not found: $core_shim_link_option" >&2
            exit 1
        fi

        # Compile and link with the same MSYS2 MinGW64 g++ that packaged
        # OpenCV, not GNAT-FSF g++ from PATH.
        mingw_prefix=$(dirname "$library_dir")
        cxx_candidate="${mingw_prefix}/bin/g++.exe"
        if [ ! -f "$cxx_candidate" ]; then
            cxx_candidate="${mingw_prefix}/bin/g++"
        fi
        if [ ! -f "$cxx_candidate" ]; then
            echo "error: MSYS2 MinGW64 g++ was not found at ${mingw_prefix}/bin/g++.exe" >&2
            echo "error: install mingw-w64-x86_64-gcc in the same prefix as OpenCV" >&2
            exit 1
        fi
        if ! command -v cygpath >/dev/null 2>&1; then
            echo "error: cygpath is required to record a GPR-compatible MSYS2 g++ path" >&2
            exit 1
        fi
        cxx_driver=$(cygpath -m "$cxx_candidate")
        case "$cxx_driver" in
            *gnat_native*)
                echo "error: C++ driver resolved to the GNAT toolchain: $cxx_driver" >&2
                exit 1
                ;;
        esac
        echo "External C++ driver: $cxx_driver"
        ;;
esac

case "$include_dir$library_dir$cxx_driver$cxx_sysroot$opencv_imgproc_link_option$opencv_core_link_option$core_shim_link_option" in
    *\"*)
        echo "error: OpenCV paths containing double quotes are unsupported" >&2
        exit 1
        ;;
esac

mkdir -p config

cat >"$output" <<EOF_GPR
--  Generated by scripts/configure_opencv.sh; do not edit.
abstract project OpenCV_Imgproc_Install is
   type Shim_Build_Kind is
     ("Static_PIC", "Relocatable", "External_Relocatable");
   type Cxx_Toolchain_Kind is ("GNU", "Apple_Clang");
   Shim_Build : Shim_Build_Kind := "${shim_build}";
   Cxx_Toolchain : Cxx_Toolchain_Kind := "${cxx_toolchain}";
   Include_Switch := "-I${include_dir}";
   Library_Search_Switch := "-L${library_dir}";
   OpenCV_Imgproc_Link_Option := "${opencv_imgproc_link_option}";
   OpenCV_Core_Link_Option := "${opencv_core_link_option}";
   Core_Shim_Link_Option := "${core_shim_link_option}";
   Cxx_Runtime_Switch := "${cxx_runtime_switch}";
   Cxx_Driver := "${cxx_driver}";
   Cxx_Sysroot := "${cxx_sysroot}";
end OpenCV_Imgproc_Install;
EOF_GPR

sh scripts/build_opencv_shim.sh \
    "$shim_build" \
    "$cxx_driver" \
    "$include_dir" \
    "$library_dir" \
    "$opencv_imgproc_link_option" \
    "$opencv_core_link_option" \
    "$core_shim_link_option"

echo "OpenCV package: $package"
echo "OpenCV include: $include_dir"
echo "OpenCV library: $library_dir"
