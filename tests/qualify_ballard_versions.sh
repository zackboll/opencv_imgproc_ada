#!/bin/sh
# Three exact installed prefixes, or reviewed source/build-tree overrides.
# Per-version optional variables: BALLARD_410_INCLUDE/EXTRA/GENERATED/LIBRARY,
# BALLARD_4100_*, BALLARD_500_*. Defaults use prefix pkg-config metadata.
set -eu
if [ "$#" != 3 ]; then
    echo 'usage: qualify_ballard_versions.sh PREFIX_410 PREFIX_4100 PREFIX_500' >&2
    exit 2
fi
mkdir -p tests/bin/ballard-qualification
for version in 4.1.0 4.10.0 5.0.0; do
    prefix=$1
    shift
    package=opencv4
    if [ "$version" = 5.0.0 ]; then package=opencv5; fi
    case "$version" in
        4.1.0) include=${BALLARD_410_INCLUDE:-}; extra=${BALLARD_410_EXTRA:-};
            generated=${BALLARD_410_GENERATED:-}; library=${BALLARD_410_LIBRARY:-} ;;
        4.10.0) include=${BALLARD_4100_INCLUDE:-}; extra=${BALLARD_4100_EXTRA:-};
            generated=${BALLARD_4100_GENERATED:-}; library=${BALLARD_4100_LIBRARY:-} ;;
        5.0.0) include=${BALLARD_500_INCLUDE:-}; extra=${BALLARD_500_EXTRA:-};
            generated=${BALLARD_500_GENERATED:-}; library=${BALLARD_500_LIBRARY:-} ;;
    esac
    if [ -z "$include" ]; then
        actual=$(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --modversion "$package")
        test "$actual" = "$version"
    else
        # Source-tree mode: headers and real runtime must agree exactly.
        # Host pkg-config is only a fallback for unset locations, not evidence.
        package=opencv4
        test -n "$extra" && test -n "$generated" && test -n "$library"
    fi
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" OPENCV_TEST_PACKAGE="$package" \
        OPENCV_TEST_EXPECTED_VERSION="$version" \
        OPENCV_TEST_INCLUDE="$include" OPENCV_TEST_EXTRA_INCLUDE="$extra" \
        OPENCV_TEST_GENERATED_INCLUDE="$generated" OPENCV_TEST_LIBRARY="$library" \
        OUTPUT="tests/bin/ballard-qualification/$version.txt" \
        sh tests/run_ballard_consistency.sh
done
python3 tests/compare_ballard_outputs.py \
    tests/bin/ballard-qualification/4.1.0.txt \
    tests/bin/ballard-qualification/4.10.0.txt \
    tests/bin/ballard-qualification/5.0.0.txt