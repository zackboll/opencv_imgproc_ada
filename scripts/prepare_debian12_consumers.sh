#!/bin/sh
# Builder container only. Install Core before compiling Imgproc against it.
set -eu
test "$(dpkg --print-architecture)" = amd64
# shellcheck disable=SC1091
test "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 12
test "$(pkg-config --modversion opencv4)" = 4.6.0
unset GPR_PROJECT_PATH ADA_PROJECT_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
unset LIBRARY_PATH GCC_EXEC_PREFIX COMPILER_PATH LD_LIBRARY_PATH
mkdir -p /evidence/logs /evidence/payload
compiler=${IMGPROC_QUALIFICATION_GNAT:-gnat_native=16.1.0}
alr -n --force toolchain --select "$compiler" gprbuild=26.0.1
# Immutable official snapshot: 0.5.0 is the only indexed 0.5.x here. This is
# test-only index selection, not a source/version pin in production metadata.
alr -n index --del community
alr -n index --add git+https://github.com/alire-project/alire-index#fec6b3b6c6e9eb0e17e6c1ae8bc9c194cea44106 --name minimum
alr -n index --list > /evidence/logs/index-selection.log
{
    cat /etc/os-release
    uname -m
    alr --version
    alr toolchain
    dpkg-query -W libopencv-dev libopencv-core406 libopencv-imgproc406 libstdc++6 libc6 binutils
    /usr/bin/g++ --version
} > /evidence/logs/source-system.log
cd /sources/core
alr -n build > /evidence/logs/core-build.log 2>&1
alr -n exec -- gprinstall -f -p -r --prefix=/evidence/payload/prefix-a -P opencv_core.gpr \
    > /evidence/logs/core-install.log 2>&1
cmp cpp/opencv_core_module_bridge.hpp /evidence/payload/prefix-a/include/opencv_core_module_bridge.hpp
# shellcheck disable=SC2016
alr -n exec -- sh -c 'printf "%s\n" "$PATH"' > /evidence/payload/toolchain-path.txt
alr -n exec -- sh -c 'gnat --version; gprbuild --version; gprinstall --version; gcc -print-file-name=adalib' \
    > /evidence/logs/toolchain.log
case "$compiler" in
    gnat_native=16.1.0) grep '16.1.0' /evidence/logs/toolchain.log ;;
    gnat_external=12.2.0) grep '12.2.0' /evidence/logs/toolchain.log ;;
    *) echo "unqualified compiler selection: $compiler" >&2; exit 1 ;;
esac
cd /sources/imgproc
if [ "$compiler" = gnat_external=12.2.0 ]; then
    # GNAT 12 production/independent consumer qualification, not full AUnit.
    # The strict development AUnit attempt is retained separately: its Guil
    # internal-ABI unit triggers Core compile-time representation diagnostics.
    alr -n build > /evidence/logs/imgproc-production.log 2>&1
    python3 scripts/verify_release_selection.py alire/alire.lock \
        --core-version 0.5.0 > /evidence/logs/core-selection.log
    cp alire/alire.lock /evidence/logs/production-alire.lock
    echo 'NOT RUN: GNAT 12 full AUnit; separate failed development-harness evidence retained' \
        > /evidence/logs/aunit.log
else
    # Full authoritative test suite uses the existing development path pin.
    alr -n -C tests run > /evidence/logs/aunit.log 2>&1
    python3 scripts/verify_release_selection.py tests/alire/alire.lock \
        --core-version 0.5.0 --allow-parent-pin > /evidence/logs/core-selection.log
    cp tests/alire/alire.lock /evidence/logs/aunit-alire.lock
    grep -E '^Successful Tests:[[:space:]]+1178$' /evidence/logs/aunit.log
    grep -E '^Failed Assertions:[[:space:]]+0$' /evidence/logs/aunit.log
    grep -E '^Unexpected Errors:[[:space:]]+0$' /evidence/logs/aunit.log
fi
# Fresh copy, no Core checkout accessible to this project or its search paths.
mkdir /tmp/imgproc-installed-build
cp -a src cpp config scripts ./*.gpr /tmp/imgproc-installed-build/
cd /tmp/imgproc-installed-build
sh scripts/configure_opencv.sh > /evidence/logs/imgproc-configure.log 2>&1
PATH=$(cat /evidence/payload/toolchain-path.txt); export PATH
GPR_PROJECT_PATH=/evidence/payload/prefix-a/share/gpr; export GPR_PROJECT_PATH
unset OPENCV_CORE_ALIRE_PREFIX OPENCV_IMGPROC_ALIRE_PREFIX ALIRE
gprbuild -P opencv_imgproc.gpr -v > /evidence/logs/imgproc-build-installed-core.log 2>&1
gprinstall -f -p --prefix=/evidence/payload/prefix-a -P opencv_imgproc_shim.gpr \
    > /evidence/logs/imgproc-shim-install.log 2>&1
gprinstall -f -p --prefix=/evidence/payload/prefix-a -P opencv_imgproc.gpr \
    > /evidence/logs/imgproc-install.log 2>&1
cp -a /sources/imgproc/tests/installed_consumers /evidence/payload/consumers
cp /sources/imgproc/scripts/consume_debian12_install.sh /evidence/payload/consume.sh
cp -a /root/.local/share/alire/toolchains /evidence/toolchains
find /evidence/payload/prefix-a -type f -print | sort > /evidence/logs/install-inventory.log
find /evidence/payload/prefix-a -type f -exec sha256sum {} + > /evidence/logs/install-sha256.log
echo 'Core and Imgproc independently installed PASS'