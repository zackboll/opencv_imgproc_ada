#!/bin/sh
# Run as root only in a disposable Debian 12 container; never an existing SDK.
set -eu
sysroot=${1:?usage: prepare_debian12_target.sh NEW_SYSROOT EVIDENCE}
evidence=${2:?evidence directory required}
test ! -e "$sysroot"
test "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 12
mkdir -p "$sysroot" "$evidence/packages"
dpkg --add-architecture arm64
apt-get update
cp -a /etc/apt/sources.list.d "$evidence/apt-sources"
apt-get -y --download-only --no-install-recommends install \
    libopencv-dev:arm64 libc6-dev:arm64 libstdc++-12-dev:arm64
for package in /var/cache/apt/archives/*.deb; do
    arch=$(dpkg-deb -f "$package" Architecture)
    case "$arch" in arm64|all)
        dpkg-deb -f "$package" Package Version Architecture >> "$evidence/packages.txt"
        sha256sum "$package" >> "$evidence/package-sha256.txt"
        cp "$package" "$evidence/packages/"
        dpkg-deb -x "$package" "$sysroot"
        ;; esac
done
python3 "$(dirname -- "$0")/../tests/cross/stage_debian_alternatives.py" \
    "$sysroot" "$evidence/packages" "$evidence/alternatives.txt"
dpkg-query -W > "$evidence/compiler-packages.txt"
test -f "$sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/opencv4.pc"