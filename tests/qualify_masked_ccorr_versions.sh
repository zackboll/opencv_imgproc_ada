#!/bin/sh
set -eu
if [ "$#" != 3 ]; then
    echo 'usage: qualify_masked_ccorr_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500' >&2
    exit 2
fi
mkdir -p tests/bin/masked-ccorr-qualification
for version in 4.1.0 4.10.0 5.0.0; do
    prefix=$1
    shift
    package=opencv4
    if [ "$version" = 5.0.0 ]; then package=opencv5; fi
    path="$prefix/lib/pkgconfig:$prefix/lib/x86_64-linux-gnu/pkgconfig"
    actual=$(PKG_CONFIG_PATH="$path" pkg-config --modversion "$package")
    test "$actual" = "$version"
    PKG_CONFIG_PATH="$path" OPENCV_TEST_PACKAGE="$package" \
        OUTPUT="tests/bin/masked-ccorr-qualification/$version.txt" \
        sh tests/run_masked_ccorr_consistency.sh
done
python3 tests/compare_masked_ccorr_outputs.py \
    tests/bin/masked-ccorr-qualification/4.1.0.txt \
    tests/bin/masked-ccorr-qualification/4.10.0.txt \
    tests/bin/masked-ccorr-qualification/5.0.0.txt