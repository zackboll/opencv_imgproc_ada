#!/bin/bash
# Run through the tests Alire environment. Isolate each provider's generated
# projects/artifacts instead of mutating shared Alire dependency deployments.
set -euo pipefail
if test "$#" != 4; then
    echo 'usage: qualify_native_thread_versions.sh PREFIX_410 PREFIX_460 PREFIX_500 EVIDENCE' >&2
    exit 2
fi
root=$(cd "$(dirname "$0")/.." && pwd)
core=${OPENCV_CORE_ALIRE_PREFIX:?}
aunit=$(dirname "$(find "${GPR_PROJECT_PATH%%:*}" -name aunit.gpr -print -quit)")
evidence=$4
mkdir -p "$evidence"
evidence=$(cd "$evidence" && pwd)
prefixes=("$1" "$2" "$3")
versions=(4.1.0 4.6.0 5.0.0)
for index in 0 1 2; do
    version=${versions[$index]}
    prefix=${prefixes[$index]}
    cell="$evidence/$version"
    mkdir -p "$cell/imgproc" "$cell/core"
    git -C "$root" archive HEAD | tar -x -C "$cell/imgproc"
    # Include the uncommitted test correction when qualifying before commit.
    for file in tests/native/reference.cpp tests/src/connected_component_tests.adb \
        tests/src/connected_component_tests.ads tests/src/tests.adb; do
        cp "$root/$file" "$cell/imgproc/$file"
    done
    cp -a "$root/config" "$cell/imgproc/"
    mkdir -p "$cell/imgproc/tests/config"
    cp -a "$root/tests/config/." "$cell/imgproc/tests/config/"
    cp -a "$core/." "$cell/core/"
    rm -rf "$cell/core/obj" "$cell/core/lib"
    export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
    export LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export OPENCV_CORE_ALIRE_PREFIX="$cell/core"
    export GPR_PROJECT_PATH="$cell/core:$cell/imgproc:$aunit"
    package=opencv4
    if test "$version" = 5.0.0; then package=opencv5; fi
    test "$(pkg-config --modversion "$package")" = "$version"
    (cd "$cell/core"; sh scripts/configure_opencv.sh) > "$cell/configure.log" 2>&1
    (cd "$cell/imgproc"; sh scripts/configure_opencv.sh
        gprbuild -P opencv_imgproc.gpr -p -j0
        cd tests; sh build_native_reference.sh
        gprbuild -P tests.gpr -p -j0) > "$cell/build.log" 2>&1
    "$cell/imgproc/tests/bin/tests" > "$cell/aunit.log" 2>&1
    grep -E '^Total Tests Run: *1178$' "$cell/aunit.log"
    grep -E '^Successful Tests: *1178$' "$cell/aunit.log"
    grep -E '^Failed Assertions: *0$' "$cell/aunit.log"
    grep -E '^Unexpected Errors: *0$' "$cell/aunit.log"
    grep 'CCL ' "$cell/aunit.log"
    if test "$version" = 4.1.0; then
        grep -Fx 'CCL 4.1 parallel rejection: EXERCISED' "$cell/aunit.log"
    fi
    ldd "$cell/imgproc/tests/bin/tests" > "$cell/loader.log"
    grep -F "$prefix/lib/libopencv_imgproc" "$cell/loader.log"
    echo "PASS native-thread full suite $version"
done