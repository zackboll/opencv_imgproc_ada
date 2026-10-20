#!/bin/sh
# Same explicit interface; a fresh prefix and automatic CGPR are mandatory.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
exec sh "$root/scripts/cross_install_imgproc.sh" --qualify "$@"