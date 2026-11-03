#!/usr/bin/env python3
"""Active exact R3 authority; historical campaigns keep their own identities."""
import json
from pathlib import Path
import subprocess
import tomllib

from install_released_gnatdoc import digest, require

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.5.2'
ORIGIN = 'aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d'
TREE = '3340347a8cd3945c36e9ecde9e4a4798efbd91f7'
AUTHORITY_SHA = '517a954951c2bd73ccf8bc2c45e923843f17d2db9e2349638edc8ca9a19cb3e5'


def authority(root=ROOT):
    path = root / 'docs/evidence/gnatdoc009/r3/source-authority.json'
    require(not path.is_symlink() and digest(path.read_bytes()) == AUTHORITY_SHA,
            'forged R3 source authority')
    record = json.loads(path.read_text())
    require((record['version'], record['origin'], record['tree']) == (VERSION, ORIGIN, TREE),
            'wrong R3 source authority identity')
    manifest = root / 'docs/evidence/gnatdoc009/r3/indexed-release.toml'
    require(digest(manifest.read_bytes()) == record['release_manifest_sha256'],
            'forged indexed release manifest')
    return record


def check_solution(lock, manifest):
    require(not manifest.get('pins') and
            [d['opencv_core'] for d in manifest['depends-on'] if 'opencv_core' in d] == ['~0.5.0'],
            'library constraint or pins changed')
    selected = [s for s in lock['solution']['state'] if s['crate'] == 'opencv_core']
    require(len(selected) == 1 and selected[0]['fulfilment'] == 'solved' and
            selected[0]['pinned'] is False and selected[0]['versions'] == '~0.5.0' and
            selected[0]['release']['version'] == VERSION and
            selected[0]['release']['origin'] == {
                'commit': ORIGIN, 'url': 'git+https://github.com/zackboll/opencv_core_ada.git'},
            'SOURCE_AUTHORITY_CHANGED: normal resolver must select exact indexed Core 0.5.2 origin')
    return selected[0]


def check_source(core, record):
    require(core.is_dir() and not core.is_symlink() and
            not any(p.is_symlink() for p in (core / 'src').rglob('*')), 'unsafe Core source')
    actual = {p.relative_to(core).as_posix(): digest(p.read_bytes())
              for p in (core / 'src').rglob('*') if p.is_file()}
    require(actual == record['source_sha256'], 'resolved Core source differs from exact R3 source inventory')


def checked_resolution(root, core):
    record = authority(root)
    lock_path = root / 'alire/alire.lock'
    manifest_path = root / 'alire.toml'
    check_solution(tomllib.loads(lock_path.read_text()), tomllib.loads(manifest_path.read_text()))
    check_source(core, record)
    receipt = json.loads((root / 'obj/docs/core-resolution.json').read_text())
    require(receipt == {'schema_version': 1, 'root': str(root.resolve()),
            'source': str(core.resolve()), 'version': VERSION, 'origin': ORIGIN,
            'lock_sha256': digest(lock_path.read_bytes()),
            'manifest_sha256': digest(manifest_path.read_bytes()),
            'authority_sha256': AUTHORITY_SHA, 'resolution': 'alr update --online; unpinned'},
            'copied/stale Alire solution or different live reconstruction dependency')
    return record


def resolve(root=ROOT):
    record = authority(root)
    # Always re-solve with the current community index, never accept a retained
    # lock merely because it still happens to satisfy the broad library range.
    subprocess.run(['alr', '-n', 'update', '--online'], cwd=root, check=True, timeout=180)
    lock = root / 'alire/alire.lock'
    manifest = root / 'alire.toml'
    check_solution(tomllib.loads(lock.read_text()), tomllib.loads(manifest.read_text()))
    core = Path(subprocess.run(['alr', 'exec', '--', 'printenv', 'OPENCV_CORE_ALIRE_PREFIX'],
                cwd=root, check=True, capture_output=True, text=True, timeout=120).stdout.strip())
    check_source(core, record)
    destination = root / 'obj/docs'
    destination.mkdir(parents=True, exist_ok=True)
    receipt = {'schema_version': 1, 'root': str(root.resolve()), 'source': str(core.resolve()),
               'version': VERSION, 'origin': ORIGIN, 'lock_sha256': digest(lock.read_bytes()),
               'manifest_sha256': digest(manifest.read_bytes()), 'authority_sha256': AUTHORITY_SHA,
               'resolution': 'alr update --online; unpinned'}
    (destination / 'core-resolution.json').write_text(json.dumps(receipt, sort_keys=True, indent=2) + '\n')
    checked_resolution(root, core)


if __name__ == '__main__':
    resolve()