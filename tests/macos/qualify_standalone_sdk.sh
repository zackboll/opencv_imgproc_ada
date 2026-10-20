#!/bin/bash
# Native ARM64 proof of production GPR SDK selection, not SDKROOT.
# Run from the checkout root; retain evidence even when qualification fails.
set -euo pipefail

root=$PWD
evidence=${RUNNER_TEMP:?}/imgproc-standalone-sdk
mkdir -p "$evidence"
exec > >(tee "$evidence/qualification.log") 2>&1
trap 'status=$?; echo "Qualification exit status: $status" > "$evidence/status.txt"' EXIT
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
test "${SDKROOT+x}" != x
test "${LIBRARY_PATH+x}" != x
echo 'SDKROOT=UNSET; LIBRARY_PATH=UNSET'
test "$(git rev-parse HEAD)" = "${EXPECTED_IMGPROC_HEAD:?}"
baseline_core_commit=386c5360ac51f2b62e522853d94290aec4ee14a0
candidate_core_commit=f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f
baseline_commit=5f56b40f9cfe76ae0c4f829f9d1eae0861002768

echo "Imgproc SHA / tree: $(git rev-parse HEAD 'HEAD^{tree}')"
echo "Historical Core: indexed 0.4.1 / $baseline_core_commit"
echo "Candidate Core: indexed 0.5.0 / $candidate_core_commit"
echo "Provider: ${QUALIFY_PROVIDER:?}"
echo "Runner image: ${ImageOS:?} / ${ImageVersion:?}"
uname -a
sw_vers
xcode-select -p
xcodebuild -version
sdk=$(xcrun --sdk macosx --show-sdk-path)
xcrun --sdk macosx --show-sdk-version
echo "Selected Xcode SDK: $sdk"
case "$sdk" in
    "$(xcode-select -p)"/Platforms/MacOSX.platform/Developer/SDKs/*) ;;
    *) echo 'Selected SDK is not inside Xcode'; exit 1 ;;
esac
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
clt_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
if test -f "$clt_sdk/SDKSettings.json"; then
    plutil -p "$clt_sdk/SDKSettings.json"
    head -8 "$clt_sdk/usr/lib/libSystem.tbd"
fi
alr -n toolchain

ada_tool() {
    # Alire's deployed compiler manifest can reintroduce LIBRARY_PATH even
    # when the invoking shell has it unset. Remove both variables after
    # Alire sets up PATH/project resolution, immediately before each tool.
    # shellcheck disable=SC2016
    alr -n exec -- env -u SDKROOT -u LIBRARY_PATH \
        sh -c 'test "${SDKROOT+x}" != x; test "${LIBRARY_PATH+x}" != x; exec "$@"' sh "$@"
}

select_core() {
    local version=$1 core_commit=$2
    # Controlled version pin, NOT pin-free publication-consumer evidence.
    # Both selections come from the official index, never source/path pins.
    # Manifest changes exist only in the disposable runner checkouts.
    alr -n pin "opencv_core=$version"
    alr -n with --solve
    alr -n -C tests with --solve
    grep -F "$core_commit" alire/alire.lock
    grep -F "$core_commit" tests/alire/alire.lock
    alr -n exec -- gnat --version
    alr -n exec -- gcc -v
    alr -n exec -- gcc -dumpfullversion | grep -Fx 16.1.0
    # The indexed 26.0.1 archive's executable reports GPRBUILD 26.0.0.
    # Verify the selected Alire release, and retain the actual banner too.
    alr -n toolchain | grep -E '^gprbuild +26\.0\.1 +Default'
    alr -n exec -- gprbuild --version
    alr -n exec -- gcc -print-sysroot
    gnat_ld=$(alr -n exec -- gcc -print-prog-name=ld)
    echo "GNAT bundled linker: $gnat_ld"
    "$gnat_ld" -v || true
    # Record the distinction between the invoking shell and Alire's injected
    # toolchain environment. Never let that injection reach an Ada link.
    # shellcheck disable=SC2016
    alr -n exec -- sh -c 'printf "Alire SDKROOT=%s; LIBRARY_PATH=%s\n" "${SDKROOT-UNSET}" "${LIBRARY_PATH-UNSET}"'
    ada_tool sh -c 'echo "Ada tool boundary: SDKROOT=UNSET; LIBRARY_PATH=UNSET"'
}

# Real old/new source, same provider/toolchain/runner/environment. Never
# classify an unrelated compilation or installation failure as GNAT-FSF #112.
cd "$root/../baseline"
test "$(git rev-parse HEAD)" = "$baseline_commit"
echo "Baseline SHA / tree: $(git rev-parse HEAD 'HEAD^{tree}')"
select_core 0.4.1 "$baseline_core_commit"
# Build the library closure first: the test-only native oracle links the Core
# shim and cannot run on a fresh deployment before that shim exists.
alr -n action -r pre-build > "$evidence/baseline-library-configure.log" 2>&1
ada_tool gprbuild -P opencv_imgproc.gpr -p -v \
    > "$evidence/baseline-library-build.log" 2>&1
# Generate the test oracle using its own action, then control the Ada link.
alr -n -C tests action -r pre-build > "$evidence/baseline-configure.log" 2>&1
if (cd tests; ada_tool gprbuild -P tests.gpr -p -v -largs -Wl,-t) \
    > "$evidence/baseline-link.log" 2>&1; then
    echo NOT_REPRODUCED | tee "$evidence/control-result.txt"
    echo '::warning::Old Imgproc links on this image; regression not reproduced'
else
    if grep -F "$clt_sdk/usr/lib/libSystem.tbd" "$evidence/baseline-link.log" &&
       grep -F 'arm64e.x1-macos' "$evidence/baseline-link.log" &&
       grep -F 'unknown architecture' "$evidence/baseline-link.log"; then
        echo REPRODUCED_GNAT_FSF_112 | tee "$evidence/control-result.txt"
    else
        echo BASELINE_FAILED_UNRELATED | tee "$evidence/control-result.txt"
        tail -100 "$evidence/baseline-link.log"
        exit 1
    fi
fi
cp alire/alire.lock "$evidence/baseline-library-alire.lock"
cp tests/alire/alire.lock "$evidence/baseline-tests-alire.lock"
cd "$root"
select_core 0.5.0 "$candidate_core_commit"
cp alire/alire.lock "$evidence/library-alire.lock"
cp tests/alire/alire.lock "$evidence/tests-alire.lock"
core=$(alr -n exec -- printenv OPENCV_CORE_ALIRE_PREFIX)
# Alire deploys Git origins without .git. The verified lockfile records the
# immutable origin; its authoritative tree was refreshed before this change.
echo "Core accepted origin SHA: $candidate_core_commit"
echo 'Core accepted origin tree: bc9396053cde0eaabae513dddf64ad45084a64ca'
echo "Core deployed source: $core"

alr -n action -r pre-build 2>&1 | tee "$evidence/configure.log"
ada_tool gprbuild -P opencv_imgproc.gpr -p -v \
    2>&1 | tee "$evidence/production-build.log"
config=config/opencv_imgproc_install.gpr
cp "$config" "$evidence/"
grep -F "Cxx_Sysroot := \"$sdk\";" "$config"
grep -F 'Shim_Build : Shim_Build_Kind := "Relocatable";' "$config"
grep -F 'Cxx_Toolchain : Cxx_Toolchain_Kind := "Apple_Clang";' "$config"
library=$(sed -n 's/.*Library_Search_Switch := "-L\(.*\)";/\1/p' "$config")
case "$library" in
    "${EXPECTED_OPENCV_PREFIX:?}"/*) ;;
    *) echo "Wrong provider: $library"; exit 1 ;;
esac
physical_library=$(cd "$library" && pwd -P)
echo "OpenCV provider library: $library -> $physical_library"

check_trace() {
    local log=$1
    # Require a real GCC driver command, not merely a GPR/config echo.
    grep -E '(^|/)(gcc|g\+\+)( |")' "$log" | grep -F -- "--sysroot=$sdk"
    grep -Fx "$sdk/usr/lib/libSystem.tbd" "$log"
    # Reject any CLT selection, including the incompatible CLT 27 SDK.
    if grep -E '/Library/Developer/CommandLineTools/SDKs/[^ ]*/usr/lib/libSystem\.tbd' "$log"; then
        echo 'CLT libSystem selected instead of Xcode'; exit 1
    fi
}

check_dependencies() {
    local binary=$1
    otool -L "$binary"
    otool -l "$binary" | grep -A4 LC_BUILD_VERSION
    otool -L "$binary" | grep -F /usr/lib/libSystem.B.dylib
}

check_dependencies lib/libopencv_imgproc_shim.dylib
otool -L lib/libopencv_imgproc_shim.dylib | grep -F /usr/lib/libc++

# No test command supplies a sysroot: production GPR alone must propagate it.
alr -n -C tests action -r pre-build 2>&1 | tee "$evidence/tests-configure.log"
(cd tests; ada_tool gprbuild -P tests.gpr -p -v -largs -Wl,-t) \
    2>&1 | tee "$evidence/corrected-tests-link.log"
check_trace "$evidence/corrected-tests-link.log"
check_dependencies tests/bin/tests
DYLD_PRINT_LIBRARIES=1 tests/bin/tests \
    > "$evidence/aunit.log" 2> "$evidence/aunit-dyld.log"
cat "$evidence/aunit.log"
grep -E '^Total Tests Run: *1178$' "$evidence/aunit.log"
grep -E '^Successful Tests: *1178$' "$evidence/aunit.log"
grep -E '^Failed Assertions: *0$' "$evidence/aunit.log"
grep -E '^Unexpected Errors: *0$' "$evidence/aunit.log"
grep -F libopencv_imgproc_shim "$evidence/aunit-dyld.log"
grep -F -e "$library/libopencv_imgproc." \
    -e "$physical_library/libopencv_imgproc." "$evidence/aunit-dyld.log"

ada_tool gprbuild -P opencv_imgproc.gpr -p -f -v \
    -XOPENCV_IMGPROC_LIBRARY_TYPE=relocatable -largs -Wl,-t \
    2>&1 | tee "$evidence/relocatable-library-link.log"
check_trace "$evidence/relocatable-library-link.log"
check_dependencies lib/libopencv_imgproc_ada.dylib

# Install the normal static-PIC Ada library and its GPR-built macOS shim.
# Unlike Geometry's external shim, Imgproc's shim is installed by GPRinstall.
ada_tool gprbuild -P opencv_imgproc.gpr -p -f
prefix="$evidence/installed"
ada_tool gprinstall -P opencv_imgproc.gpr -p -r --prefix="$prefix" \
    2>&1 | tee "$evidence/install.log"
cp -R "$prefix/share/gpr" "$evidence/installed-projects"
grep -R -F -- "--sysroot=$sdk" "$prefix/share/gpr"

# Hide source libraries so neither link nor dyld can accidentally use them.
mv "$root/lib" "$root/lib-standalone-unavailable"
mv "$core/lib" "$core/lib-standalone-unavailable"
restore() {
    status=$?
    mv "$root/lib-standalone-unavailable" "$root/lib"
    mv "$core/lib-standalone-unavailable" "$core/lib"
    echo "Qualification exit status: $status" > "$evidence/status.txt"
}
trap restore EXIT
consumer="$evidence/consumer"
mkdir -p "$consumer"
cp tests/installed_consumers/ada_consumer.gpr \
    tests/installed_consumers/installed_ada.adb \
    tests/installed_consumers/processing_check.ad[bs] "$consumer/"
for mode in installed relocated; do
    if test "$mode" = relocated; then
        moved="$evidence/relocated/a-longer-installation-root"
        mkdir -p "$moved"
        mv "$prefix" "$moved/prefix"
        prefix="$moved/prefix"
        rm -rf "${consumer:?}/obj-ada" "${consumer:?}/bin"
    fi
    # Leave the checkout too: GPRbuild searches CWD before GPR_PROJECT_PATH.
    # shellcheck disable=SC2016
    ada_tool env -u ADA_PROJECT_PATH -u ADA_INCLUDE_PATH -u ADA_OBJECTS_PATH \
        GPR_PROJECT_PATH="$prefix/share/gpr" \
        sh -c 'cd "$1"; shift; exec "$@"' sh "$consumer" \
        gprbuild -P ada_consumer.gpr -p -v -largs -Wl,-t \
        2>&1 | tee "$evidence/$mode-consumer-link.log"
    check_trace "$evidence/$mode-consumer-link.log"
    grep -F "$prefix/lib/opencv_imgproc/libopencv_imgproc_ada.a" \
        "$evidence/$mode-consumer-link.log"
    if grep -F -e "$root/lib/" -e "$core/lib/" \
        "$evidence/$mode-consumer-link.log"; then exit 1; fi
    check_dependencies "$consumer/bin/installed_ada"
    DYLD_PRINT_LIBRARIES=1 "$consumer/bin/installed_ada" \
        > "$evidence/$mode-consumer-run.log" 2> "$evidence/$mode-consumer-dyld.log"
    cat "$evidence/$mode-consumer-run.log"
    grep -F 'consumer PASS' "$evidence/$mode-consumer-run.log"
    grep -F "$prefix/lib/opencv_imgproc_shim/libopencv_imgproc_shim.dylib" \
        "$evidence/$mode-consumer-dyld.log"
    if grep -F -e "$root/" -e "$core/" "$evidence/$mode-consumer-dyld.log"; then exit 1; fi
done
echo 'PASS standalone GPR SDK linking, 1178/1178 AUnit, installed and relocated consumers'