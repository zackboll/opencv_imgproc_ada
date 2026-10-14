#!/bin/sh
# Explicit target-only entry point. No implicit native/host fallback.
set -eu
exec python3 "$(dirname -- "$0")/cross_configuration.py" configure "$@"