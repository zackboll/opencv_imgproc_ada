#!/bin/sh
# Generate and validate the public Imgproc API documentation in _site/.
# Documentation tools are installed separately; never add library dependencies.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
command -v alr >/dev/null
command -v python3 >/dev/null
# Guides need the pinned Markdown renderer (docs/requirements.txt), installed
# in a separate documentation environment, for example .doc-tools/markdown.
python=${DOC_PYTHON:-python3}
test "$(alr --version)" = 'alr 2.1.1' || {
    echo 'error: documentation requires Alire 2.1.1' >&2; exit 1;
}
# alire.toml pins opencv_core to this sibling checkout. Core sources are
# needed for name resolution only; they are not published.
test -f ../core/opencv_core.gpr || {
    echo 'error: documentation requires the opencv_core checkout at ../core' >&2
    exit 1
}
prefix=${GNATDOC_PREFIX:-"$root/.doc-tools/gnatdoc-26.0.0"}
if [ ! -x "$prefix/bin/gnatdoc" ]; then
    alr -n install --prefix="$prefix" gnatdoc_bin=26.0.0
fi
# This release prints its version successfully but returns status 1.
version=$("$prefix/bin/gnatdoc" --version 2>&1 || true)
test "$version" = 'GNATdoc 26.0.0 (20260415)' || {
    echo "error: unqualified GNATdoc: $version" >&2; exit 1;
}
echo "$version"
# Resolve the library environment and its supported OpenCV configuration.
# This builds only the library, not the test crate or unrelated applications.
alr -n build
alr exec -- gnat --version | grep -q '^GNAT 16\.1\.0$' || {
    echo 'error: documentation requires GNAT 16.1.0' >&2; exit 1;
}
alr exec -- gprbuild --version | grep -q '^GPRBUILD 26\.0\.0 (2026-04-15)' || {
    echo 'error: documentation requires the GPRbuild 26.0.1 Alire release' >&2; exit 1;
}
# Fixed repository-owned output path: never delete a caller-selected directory.
rm -rf -- "$root/_site"
mkdir -p _site/api obj/docs obj/docs-internal
if ! alr exec -- "$prefix/bin/gnatdoc" -P docs_api.gpr \
    --backend html --generate public --style leading --warnings \
    -O "$root/_site/api" > obj/docs/gnatdoc.log 2>&1; then
    cat obj/docs/gnatdoc.log >&2
    exit 1
fi
# GNATdoc can report parsing/resolution errors while producing partial output.
if grep -Ei '(^|[[:space:]])(error:|fatal:|ignore file due to)' obj/docs/gnatdoc.log; then
    echo 'error: GNATdoc reported incomplete generation' >&2
    exit 1
fi
warnings=$(grep -c 'warning:' obj/docs/gnatdoc.log || true)
echo "GNATdoc: $warnings documentation warnings (see obj/docs/gnatdoc.log)"
# Ratchet: new warnings fail, and so does a baseline that still lists fixed ones.
python3 scripts/compare_gnatdoc_warnings.py --fail-on-removed \
    docs/gnatdoc-warning-baseline.txt obj/docs/gnatdoc.log
cp docs/index.html _site/index.html
# Presentation: theme metadata, source-backed type links, then Ada coloring.
# Each step verifies the previous ones and records what it changed.
python3 scripts/install_gnatdoc_theme.py _site/api
python3 scripts/link_gnatdoc_types.py _site/api
python3 scripts/highlight_gnatdoc_ada.py _site/api
# Operation-level browser in the native index; declaration pages are unchanged.
python3 scripts/enhance_gnatdoc_navigation.py _site/api
# Developer guides with compiled examples and verified API anchors.
"$python" scripts/render_gnatdoc_guides.py _site
"$python" scripts/validate_docs.py _site
# Declaration, overload and member documentation coverage, with the same ratchet.
python3 scripts/check_doc_coverage.py --fail-on-removed \
    docs/gnatdoc-coverage-baseline.txt _site
# Zero warnings and complete coverage were reached; neither baseline may
# record a gap again, so every new public declaration must be documented.
if grep -q '[^[:space:]]' docs/gnatdoc-warning-baseline.txt \
    docs/gnatdoc-coverage-baseline.txt; then
    echo 'error: documentation baselines must stay empty' >&2
    exit 1
fi
