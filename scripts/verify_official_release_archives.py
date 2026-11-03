#!/usr/bin/env python3
"""Independent official sdist/wheel/source comparison; never installs the sdist."""
import json
from pathlib import Path
import tarfile
import tempfile

from install_released_gnatdoc import (
    MEMBERS, PROVENANCE_HASH, SDIST_HASH, SUMS_HASH, WHEEL, WHEEL_HASH,
    archive, digest, download, require, tagged_source,
)


def verify():
    with tempfile.TemporaryDirectory(prefix='imgproc-release-archives-') as tmp:
        root = Path(tmp)
        files = ((WHEEL, WHEEL_HASH, 94500),
                 ('ada_gnatdoc_enhancer-0.1.1.tar.gz', SDIST_HASH, 2179185),
                 ('release-provenance.json', PROVENANCE_HASH, 24655822),
                 ('SHA256SUMS', SUMS_HASH, 300))
        for name, sha, size in files:
            download(name, root / name, sha, size)
        wheel = archive(root / WHEEL, WHEEL_HASH, MEMBERS)
        tagged_source(root / 'git', wheel)
        packaged = {}
        members = {}
        total = 0
        with tarfile.open(root / 'ada_gnatdoc_enhancer-0.1.1.tar.gz', 'r:gz') as source:
            for item in source:
                path = Path(item.name)
                require(not path.is_absolute() and '..' not in path.parts and
                        item.name not in members and (item.isdir() or item.isfile()),
                        'unsafe or duplicate official sdist member')
                members[item.name] = None
                if item.isfile():
                    total += item.size
                    require(item.size <= 8_000_000 and total <= 32_000_000,
                            'oversized sdist member inventory')
                    data = source.extractfile(item).read()
                    members[item.name] = digest(data)
                    prefix = 'ada_gnatdoc_enhancer-0.1.1/src/'
                    if item.name.startswith(prefix + 'ada_gnatdoc_enhancer/'):
                        packaged[item.name.removeprefix(prefix)] = data
        expected = {k: v for k, v in wheel.items() if k.startswith('ada_gnatdoc_enhancer/')}
        require(packaged == expected, 'official sdist/wheel package member bytes differ')
        return {'archives': {name: sha for name, sha, _ in files},
                'sdist_member_sha256': members, 'package_members_equal_tagged_source_and_wheel': len(packaged),
                'sdist_installed': False}


if __name__ == '__main__':
    print(json.dumps(verify(), sort_keys=True, indent=2))