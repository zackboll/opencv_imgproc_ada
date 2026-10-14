#!/bin/sh
# Exact-revision disposable workspace; --prepare and --build each use a NEW path.
set -eu
exec python3 "$(dirname -- "$0")/cross_configuration.py" workspace "$@"