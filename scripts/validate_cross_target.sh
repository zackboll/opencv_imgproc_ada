#!/bin/sh
# Naming only; compiler, runtime and GPR agreement are checked separately.
set -eu
target=${1:-}
[ -n "$target" ] || { echo 'error: OPENCV_CROSS_TARGET is required' >&2; exit 1; }
printf '%s\n' "$target" | LC_ALL=C grep -Eq \
    '^aarch64-([A-Za-z0-9_]+-)?linux(-[A-Za-z0-9_]+)*$' || {
    echo 'error: only well-formed AArch64 Linux targets are supported' >&2
    exit 1
}