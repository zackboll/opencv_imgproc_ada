#!/bin/sh
# Three exact installed prefixes, or reviewed source/build-tree overrides.
# Per-version optional variables: GUIL_410_INCLUDE/EXTRA/GENERATED/LIBRARY,
# GUIL_4100_*, GUIL_500_*. Defaults use prefix pkg-config metadata.
set -eu
if [ "$#" != 3 ]; then
    echo 'usage: qualify_guil_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500' >&2
    exit 2
fi
mkdir -p tests/bin/guil-qualification
for version in 4.1.0 4.10.0 5.0.0; do
    prefix=$1
    shift
    package=opencv4
    if [ "$version" = 5.0.0 ]; then package=opencv5; fi
    case "$version" in
        4.1.0) include=${GUIL_410_INCLUDE:-}; extra=${GUIL_410_EXTRA:-};
            generated=${GUIL_410_GENERATED:-}; library=${GUIL_410_LIBRARY:-} ;;
        4.10.0) include=${GUIL_4100_INCLUDE:-}; extra=${GUIL_4100_EXTRA:-};
            generated=${GUIL_4100_GENERATED:-}; library=${GUIL_4100_LIBRARY:-} ;;
        5.0.0) include=${GUIL_500_INCLUDE:-}; extra=${GUIL_500_EXTRA:-};
            generated=${GUIL_500_GENERATED:-}; library=${GUIL_500_LIBRARY:-} ;;
    esac
    if [ -z "$include" ]; then
        actual=$(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --modversion "$package")
        test "$actual" = "$version"
    else
        package=opencv4
        test -n "$extra" && test -n "$generated" && test -n "$library"
    fi
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" OPENCV_TEST_PACKAGE="$package" \
        OPENCV_TEST_EXPECTED_VERSION="$version" \
        OPENCV_TEST_INCLUDE="$include" OPENCV_TEST_EXTRA_INCLUDE="$extra" \
        OPENCV_TEST_GENERATED_INCLUDE="$generated" OPENCV_TEST_LIBRARY="$library" \
        OUTPUT="tests/bin/guil-qualification/$version.txt" \
        sh tests/run_guil_consistency.sh
done
python3 tests/compare_guil_outputs.py \
    tests/bin/guil-qualification/4.1.0.txt \
    tests/bin/guil-qualification/4.10.0.txt \
    tests/bin/guil-qualification/5.0.0.txt
