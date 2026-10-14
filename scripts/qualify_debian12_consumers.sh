#!/bin/sh
# Adapted from Core PR #75: separate builder/consumer containers, allowlist logs.
set -eu
engine=${CONTAINER_ENGINE:-docker}
image=${IMGPROC_CONSUMER_IMAGE:-imgproc-debian12-qualification}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
core=${IMGPROC_CORE_SOURCE:-"$root/../core"}
evidence=${IMGPROC_CONSUMER_EVIDENCE:-$(mktemp -d /tmp/imgproc-ext-001.XXXXXXXX)}
artifacts=${IMGPROC_CONSUMER_ARTIFACTS:-"$evidence-artifacts"}
mkdir -p "$evidence" "$artifacts"
evidence=$(CDPATH= cd -- "$evidence" && pwd)
artifacts=$(CDPATH= cd -- "$artifacts" && pwd)
case "$artifacts/" in "$evidence/"*) echo 'artifacts must be outside private evidence' >&2; exit 1;; esac
test -z "$(ls -A "$evidence")"
test -z "$(ls -A "$artifacts")"
stage() {
    status=$?
    trap - EXIT
    printf 'Qualification exit status: %s\n' "$status" > "$evidence/status.log"
    staging=0
    "$engine" run --rm -v "$evidence:/evidence:ro" -v "$artifacts:/artifacts" "$image" sh -c '
        set -eu
        cp /evidence/status.log /artifacts/
        for file in /evidence/prepare.log /evidence/consume.log /evidence/logs/*.log /evidence/logs/*.gpr; do
            [ ! -f "$file" ] || cp "$file" /artifacts/
        done
        for dir in /evidence/logs/*-manifests; do
            [ ! -d "$dir" ] || cp -a "$dir" /artifacts/
        done
        chmod -R a+rX /artifacts
    ' || staging=$?
    if [ "$status" -ne 0 ]; then exit "$status"; fi
    exit "$staging"
}
trap stage EXIT
echo "Private evidence: $evidence; publishable artifacts: $artifacts"
mkdir -p "$evidence/logs"
{
    git -C "$core" rev-parse HEAD
    git -C "$root" rev-parse HEAD
    git -C "$root" diff --binary
    git -C "$root" status --short
    "$engine" image inspect "$image" --format '{{.Id}}'
} > "$evidence/logs/source-revisions.log"
prepare=0
"$engine" run --rm -v "$root:/sources/imgproc" -v "$core:/sources/core" \
    -v "$evidence:/evidence" "$image" sh /sources/imgproc/scripts/prepare_debian12_consumers.sh \
    > "$evidence/prepare.log" 2>&1 || prepare=$?
cat "$evidence/prepare.log"
test "$prepare" -eq 0 || exit "$prepare"
consume=0
# Do not mount private evidence wholesale: it also holds build transcripts.
"$engine" run --rm -v "$evidence/payload:/qualification" -v "$evidence/logs:/logs" \
    -v "$evidence/toolchains:/root/.local/share/alire/toolchains:ro" "$image" sh -c '
        set -eu
        rm /usr/local/bin/alr
        sh /qualification/consume.sh
    ' > "$evidence/consume.log" 2>&1 || consume=$?
cat "$evidence/consume.log"
test "$consume" -eq 0 || exit "$consume"
# Success must publish complete evidence, not merely whatever files exist.
for name in source-revisions source-system toolchain consumer-environment core-build core-install \
    aunit imgproc-configure imgproc-build-installed-core imgproc-shim-install imgproc-install \
    install-inventory install-sha256; do
    test -s "$evidence/logs/$name.log"
done
for mode in installed relocated; do
    for kind in ada mixed; do
        for suffix in build resolution run elf ldd opencv-elf; do
            test -s "$evidence/logs/$mode-$kind-$suffix.log"
        done
    done
    for project in opencv_core opencv_core_shim opencv_imgproc opencv_imgproc_shim; do
        test -s "$evidence/logs/$project.gpr"
        test -s "$evidence/logs/$mode-manifests/$project"
    done
done