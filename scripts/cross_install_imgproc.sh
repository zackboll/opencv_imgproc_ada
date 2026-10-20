#!/bin/sh
# All validation and production builds use the existing cross backend.
set -eu
exec python3 "$(dirname -- "$0")/cross_install_imgproc.py" "$@"