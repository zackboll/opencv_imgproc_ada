#!/bin/sh
# Builder container only. Install Core before compiling Imgproc against it.
set -eu
test "$(dpkg --print-architecture)" = amd64
test "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 12
test "$(pkg-config --modversion opencv4)" = 4.6.0
unset GPR_PROJECT_PATH ADA_PROJECT_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
unset LIBRARY_PATH GCC_EXEC_PREFIX COMPILER_PATH LD_LIBRARY_PATH
mkdir -p /evidence/logs /evidence/payload
alr -n --force toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
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
alr -n exec -- sh -c 'printf "%s\n" "$PATH"' > /evidence/payload/toolchain-path.txt
alr -n exec -- sh -c 'gnat --version; gprbuild --version; gprinstall --version; gcc -print-file-name=adalib' \
    > /evidence/logs/toolchain.log
grep '16.1.0' /evidence/logs/toolchain.log
# Full authoritative test suite uses the existing development path pin.
cd /sources/imgproc
alr -n -C tests run > /evidence/logs/aunit.log 2>&1
# Fresh copy, no Core checkout accessible to this project or its search paths.
mkdir /tmp/imgproc-installed-build
cp -a src cpp config scripts *.gpr /tmp/imgproc-installed-build/
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