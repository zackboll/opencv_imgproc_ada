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
version=${OPENCV_TEST_EXPECTED_VERSION:-$version}
include=${OPENCV_TEST_INCLUDE:-$include}
extra_include=${OPENCV_TEST_EXTRA_INCLUDE:-$include}
generated_include=${OPENCV_TEST_GENERATED_INCLUDE:-$include}
library=${OPENCV_TEST_LIBRARY:-$(pkg-config --variable=libdir "$package")}
binary="tests/bin/ballard-${version}-${cxx##*/}-${SANITIZE:-0}"
sanitize=
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize="-fsanitize=address,undefined -fno-omit-frame-pointer -g"
fi
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -isystem "$extra_include" \
    -isystem "$generated_include" -I"$core/cpp" \
    tests/ballard_consistency.cpp "$core/cpp/opencv_core_shim.cpp" \
    -L"$library" -Wl,-rpath,"$library" -lopencv_imgproc -lopencv_core \
    -o "$binary"
output=${OUTPUT:-tests/bin/ballard-${version}.txt}
LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$binary" > "$output"
test "$(head -n 1 "$output")" = "VERSION $version"
# Linux loader evidence is separate from canonical fixture records.
if [ "$(uname -s)" = Linux ]; then
    LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        ldd "$binary" > "$output.loader"
    grep 'libopencv_' "$output.loader"
    # Both selected libraries must resolve from the requested installation.
    for module in core imgproc; do
        resolved=$(grep "libopencv_${module}\\.so" "$output.loader" | \
            cut -d '>' -f 2 | cut -d '(' -f 1 | tr -d ' ')
        test "$(dirname "$resolved")" = "$library"
    done
fi
printf 'package=%s\nversion=%s\nheaders=%s\nextra=%s\ngenerated=%s\nlibrary=%s\n' \
    "$package" "$version" "$include" "$extra_include" \
    "$generated_include" "$library" > "$output.build"