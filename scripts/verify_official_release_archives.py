#!/usr/bin/env python3
"""Independent official sdist/wheel/source comparison; never installs the sdist."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

from install_released_gnatdoc import (
    COMMIT, MEMBERS, PROVENANCE_HASH, SDIST, SDIST_HASH, SIZES, SUMS_HASH, VERSION, WHEEL,
    WHEEL_HASH, archive, checksums, dependencies, digest, download, release_provenance,
    require, tagged_source, wheel_record,
)

# Setuptools-generated sdist metadata: the ONLY sdist files absent from the
# tagged tree. Every other sdist file must be a byte-identical tagged blob.
GENERATED = {'PKG-INFO', 'setup.cfg'} | {
    'src/ada_gnatdoc_enhancer.egg-info/' + name for name in (
        'PKG-INFO', 'SOURCES.txt', 'dependency_links.txt', 'entry_points.txt',
        'requires.txt', 'top_level.txt')}


def blob(data):
    return hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()


def verify():
    with tempfile.TemporaryDirectory(prefix='imgproc-release-archives-') as tmp:
        root = Path(tmp)
        files = ((WHEEL, WHEEL_HASH), (SDIST, SDIST_HASH),
                 ('release-provenance.json', PROVENANCE_HASH), ('SHA256SUMS', SUMS_HASH))
        for name, sha in files:
            download(name, root / name, sha, SIZES[name])
        wheel = archive(root / WHEEL, WHEEL_HASH, MEMBERS)
        record_entries = wheel_record(wheel)
        optional = dependencies(wheel)
        provenance = release_provenance((root / 'release-provenance.json').read_bytes(), wheel)
        checksums((root / 'SHA256SUMS').read_bytes())
        tagged_source(root / 'git', wheel)
        tree = {}
        for line in subprocess.run(['git', '-C', str(root / 'git'), 'ls-tree', '-r', COMMIT],
                                   check=True, capture_output=True, text=True).stdout.splitlines():
            meta, _, path = line.partition('\t')
            tree[path] = meta.split()[2]
        packaged = {}
        members = {}
        total = 0
        prefix = f'ada_gnatdoc_enhancer-{VERSION}/'
        generated = set()
        with tarfile.open(root / SDIST, 'r:gz') as source:
            for item in source:
                path = Path(item.name)
                require(not path.is_absolute() and '..' not in path.parts and
                        item.name not in members and (item.isdir() or item.isfile()) and
                        (item.name + '/').startswith(prefix),
                        'unsafe or duplicate official sdist member')
                members[item.name] = None
                if item.isfile():
                    total += item.size
                    require(item.size <= 8_000_000 and total <= 32_000_000,
                            'oversized sdist member inventory')
                    data = source.extractfile(item).read()
                    members[item.name] = digest(data)
                    relative = item.name.removeprefix(prefix)
                    if relative in GENERATED:
                        generated.add(relative)
                    else:
                        require(tree.get(relative) == blob(data),
                                'official sdist file differs from tagged source: ' + relative)
                    if relative.startswith('src/ada_gnatdoc_enhancer/'):
                        packaged[relative.removeprefix('src/')] = data
        require(generated == GENERATED, 'unexpected generated sdist metadata inventory')
        require({k: v for k, v in members.items() if v is not None} == {
            name: entry['sha256'] for name, entry in provenance['archives']['sdist']['members'].items()},
            'official sdist differs from release provenance member inventory')
        expected = {k: v for k, v in wheel.items() if k.startswith('ada_gnatdoc_enhancer/')}
        require(packaged == expected, 'official sdist/wheel package member bytes differ')
        return {'archives': {name: sha for name, sha in files},
                'archive_sizes': {name: SIZES[name] for name, _ in files},
                'wheel_members': len(wheel), 'wheel_record_entries_verified': record_entries,
                'mandatory_runtime_dependencies': [], 'optional_dependencies': optional,
                'sdist_member_sha256': members,
                'sdist_files_equal_tagged_blobs': sum(v is not None for v in members.values()) - len(GENERATED),
                'sdist_generated_metadata': sorted(GENERATED),
                'package_members_equal_tagged_source_and_wheel': len(packaged),
                'sdist_installed': False}


if __name__ == '__main__':
    print(json.dumps(verify(), sort_keys=True, indent=2))
