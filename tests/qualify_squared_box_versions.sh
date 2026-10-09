#!/bin/sh
# Three installed exact-tag prefixes, containing include and lib/pkgconfig.
# Run from the repository root. No global Alire/Core configuration is changed.
set -eu
if [ "$#" != 3 ]; then
    echo "usage: sh tests/qualify_squared_box_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500" >&2
    exit 2
fi
mkdir -p tests/bin/squared-box-qualification
for version in 4.1.0 4.10.0 5.0.0; do
    prefix=$1
    shift
    package=opencv4
    if [ "$version" = 5.0.0 ]; then package=opencv5; fi
    actual=$(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --modversion "$package")
    if [ "$actual" != "$version" ]; then
        echo "expected $version, found $actual" >&2
        exit 1
    fi
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" OPENCV_TEST_PACKAGE="$package" \
        OUTPUT="tests/bin/squared-box-qualification/$version.txt" \
        sh tests/run_squared_box_consistency.sh
done
python3 tests/compare_squared_box_outputs.py \
    tests/bin/squared-box-qualification/4.1.0.txt \
    tests/bin/squared-box-qualification/4.10.0.txt \
    tests/bin/squared-box-qualification/5.0.0.txt