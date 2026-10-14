#!/bin/sh
# Consumer container: only installed libraries, consumer sources and toolchains.
set -eu
test ! -e /sources
test ! -e /workspace/src
unset GPR_PROJECT_PATH ADA_PROJECT_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
unset LIBRARY_PATH GCC_EXEC_PREFIX COMPILER_PATH LD_LIBRARY_PATH
unset OPENCV_CORE_ALIRE_PREFIX OPENCV_IMGPROC_ALIRE_PREFIX ALIRE
PATH=$(cat /qualification/toolchain-path.txt); export PATH
if command -v alr; then
    echo 'error: Alire present in consumer environment' >&2; exit 1
fi
test "$(pkg-config --modversion opencv4)" = 4.6.0
{
    cat /etc/os-release
    uname -m
    command -v gnat gprbuild
    gnat --version
    gprbuild --version
    gcc -print-file-name=adalib
    dpkg-query -W libopencv-core406 libopencv-imgproc406 libstdc++6 libc6 binutils
    printf 'Alire absent; source checkouts not mounted; direct GPRbuild\n'
} > /logs/consumer-environment.log
for mode in installed relocated; do
    prefix=/qualification/prefix-a
    if [ "$mode" = relocated ]; then
        prefix=/qualification/relocated-longer-prefix-b
        mv /qualification/prefix-a "$prefix"
        test ! -e /qualification/prefix-a
        # GPR files themselves must be prefix-relative, not just unused paths.
        if grep -R -E '/sources/|/tmp/imgproc-installed-build|/evidence/payload/prefix-a|/qualification/prefix-a' "$prefix/share/gpr"; then
            echo 'error: nonrelocatable installed project metadata' >&2; exit 1
        fi
    fi
    GPR_PROJECT_PATH="$prefix/share/gpr"; export GPR_PROJECT_PATH
    mkdir "/qualification/$mode"
    cp /qualification/consumers/* "/qualification/$mode/"
    cd "/qualification/$mode"
    test ! -e alire.toml
    for kind in ada mixed; do
        gprbuild -P "${kind}_consumer.gpr" -v > "/logs/$mode-$kind-build.log" 2>&1
        gprls -P "${kind}_consumer.gpr" -v > "/logs/$mode-$kind-resolution.log" 2>&1
        if grep -E '/sources/|/tmp/imgproc-installed-build|/evidence/payload/' "/logs/$mode-$kind-build.log" "/logs/$mode-$kind-resolution.log"; then
            echo 'error: consumer used builder paths' >&2; exit 1
        fi
        if [ "$mode" = relocated ]; then
            if grep -F '/qualification/prefix-a/' "/logs/$mode-$kind-build.log" "/logs/$mode-$kind-resolution.log"; then
                echo 'error: consumer used original prefix' >&2; exit 1
            fi
        fi
        grep -F "$prefix/lib/opencv_core/" "/logs/$mode-$kind-build.log"
        grep -F "$prefix/lib/opencv_imgproc/" "/logs/$mode-$kind-build.log"
        "bin/installed_$kind" > "/logs/$mode-$kind-run.log" 2>&1
        grep -F 'consumer PASS' "/logs/$mode-$kind-run.log"
        readelf -h -d -Ws "bin/installed_$kind" > "/logs/$mode-$kind-elf.log"
        ldd -r "bin/installed_$kind" > "/logs/$mode-$kind-ldd.log" 2>&1
        grep 'Advanced Micro Devices X86-64' "/logs/$mode-$kind-elf.log"
        grep 'libopencv_core.so.406 => /' "/logs/$mode-$kind-ldd.log"
        grep 'libopencv_imgproc.so.406 => /' "/logs/$mode-$kind-ldd.log"
        grep 'libstdc++.so.6 => /' "/logs/$mode-$kind-ldd.log"
        if grep -E 'not found|undefined symbol' "/logs/$mode-$kind-ldd.log"; then exit 1; fi
        if [ "$mode" = relocated ]; then
            if grep -F '/qualification/prefix-a/' "/logs/$mode-$kind-elf.log" "/logs/$mode-$kind-ldd.log"; then
                echo 'error: original prefix retained in executable' >&2; exit 1
            fi
        fi
        for library in /usr/lib/x86_64-linux-gnu/libopencv_core.so.406 /usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.406; do
            readelf -h -d "$library"
            ldd -r "$library"
        done > "/logs/$mode-$kind-opencv-elf.log" 2>&1
        if grep -E 'not found|undefined symbol' "/logs/$mode-$kind-opencv-elf.log"; then exit 1; fi
    done
    cp "$prefix/share/gpr/"*.gpr /logs/
    cp -a "$prefix/share/gpr/manifests" "/logs/$mode-manifests"
done
echo 'Debian 12 independent installed/relocated Ada and mixed consumers PASS'