#!/bin/sh
set -eu
core=${OPENCV_CORE_TEST_PREFIX:-../core}
package=${OPENCV_TEST_PACKAGE:-opencv4}
cxx=${CXX:-c++}
include=$(pkg-config --variable=includedir "$package")
if [ -z "$include" ]; then
    include=$(pkg-config --variable=includedir_new "$package")
fi
library=$(pkg-config --variable=libdir "$package")
version=$(pkg-config --modversion "$package")
mkdir -p tests/bin
binary="tests/bin/masked-template-$version-${cxx##*/}-${SANITIZE:-0}"
sanitize=
if [ "${SANITIZE:-0}" = 1 ]; then
    sanitize='-fsanitize=address,undefined -fno-omit-frame-pointer -g'
fi
"$cxx" -std=c++17 -Wall -Wextra -Wpedantic -Werror $sanitize \
    -isystem "$include" -I"$core/cpp" \
    tests/masked_template_consistency.cpp "$core/cpp/opencv_core_shim.cpp" \
    -L"$library" -Wl,-rpath,"$library" -lopencv_imgproc -lopencv_core \
    -o "$binary"
output=${OUTPUT:-tests/bin/masked-template-$version.txt}
LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$binary" > "$output"
test "$(head -n 1 "$output")" = "VERSION $version"
if [ "$(uname -s)" = Linux ]; then
    LD_LIBRARY_PATH="$library${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        ldd "$binary" > "$output.loader"
    for module in core imgproc; do
        resolved=$(grep "libopencv_${module}\\.so" "$output.loader" | \
            cut -d '>' -f 2 | cut -d '(' -f 1 | tr -d ' ')
        test "$(dirname "$resolved")" = "$library"
    done
fi
printf 'version=%s\nheaders=%s\nlibrary=%s\n' \
    "$version" "$include" "$library" > "$output.build"