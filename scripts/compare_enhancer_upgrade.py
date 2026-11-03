#!/usr/bin/env python3
"""Consumer-owned v0.1.1 -> v0.1.5 publication differential (IMGPROC-GNATDOC-012).

Both publications come from the same authenticated Imgproc source and pristine
GNATdoc 26.0.0 native input. Every published file must be byte-identical except
the three changes below, and each change must match its exact upstream cause:

* api/index.html: only the navigation-filter label (upstream 27341756, v0.1.3).
* api/gnatdoc-navigation.js: tagged v0.1.1 bytes become tagged v0.1.5 bytes
  (default-router declaration restoration, upstream 0eeeadbb, v0.1.2).
* api/presentation.json: enhancer_version plus the output hashes of those two
  files; every other receipt field, including pristine native HTML, is equal.

Modes: --baseline-site compares two complete independent publications.
--baseline-venv reconstructs the v0.1.1 API from the native input with the
installer retained at the qualified v0.1.1 main commit, never the v0.1.5 one.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from install_released_gnatdoc import digest, require
from qualify_released_gnatdoc import hashes, write

ROOT = Path(__file__).resolve().parents[1]
BASELINE_COMMIT = '2160fe7a6bf612eb0b8e85b06e5e011e0c253521'
BASELINE_VERSION, CANDIDATE_VERSION = '0.1.1', '0.1.5'
OLD_LABEL = '<label for="package-search">Search documentation</label>'
NEW_LABEL = '<label for="package-search">Filter navigation links</label>'
NAVIGATION = {  # sha256 of src/ada_gnatdoc_enhancer/assets/gnatdoc-navigation.js
    BASELINE_VERSION: 'b3fb428b507844d6be76fb40156058d39a5b5f57004bde04e33b0411f68504cd',
    CANDIDATE_VERSION: 'e32e0a9fcbccffbe94268ff933905e5616a52d4d89969c52e7d539acdb102522'}
INDEX = {BASELINE_VERSION: '6ccce736335a87da898e8258aad4c341775a65b0690522a010783302e834dc04',
         CANDIDATE_VERSION: '74f9aa31e93a4a75ef25a3a808f5969b97ee6a0bdd5d2bb59a1176993f87fa50'}
CHANGED = {
    'api/index.html': {
        'upstream_commit': '27341756f9a14eb7e566791e1a947bd6c8ef5dee',
        'first_release': 'v0.1.3', 'kind': 'presentation (accessible control label)',
        'detail': 'navigation.py CONTROL label "Search documentation" -> "Filter navigation links"; '
                  'the hidden-until-JavaScript filter control, links and destinations are unchanged'},
    'api/gnatdoc-navigation.js': {
        'upstream_commit': '0eeeadbb8e1964c7fbe45e307b5c9c88a8d7b42b',
        'first_release': 'v0.1.2', 'kind': 'navigation behavior (default router)',
        'detail': 'restore approved declaration visibility after matching iframe load/hash, '
                  'Back/Forward and pageshow; URL, query, fragment and history semantics unchanged'},
    'api/presentation.json': {
        'upstream_commit': 'version-bound release metadata',
        'first_release': 'every release', 'kind': 'metadata',
        'detail': 'enhancer_version and output_sha256 of the two changed files only'},
}


def compare(baseline: Path, candidate: Path, baseline_native=None, candidate_native=None):
    a, b = hashes(baseline), hashes(candidate)
    require(set(a) == set(b) and len(a) == 14, 'publication file inventories differ')
    differing = sorted(name for name in a if a[name] != b[name])
    require(differing == sorted(CHANGED), 'unjustified publication difference: ' + repr(differing))
    old = (baseline / 'api/index.html').read_text(encoding='utf-8')
    new = (candidate / 'api/index.html').read_text(encoding='utf-8')
    require(a['api/index.html'] == INDEX[BASELINE_VERSION] and
            b['api/index.html'] == INDEX[CANDIDATE_VERSION] and
            old.count(OLD_LABEL) == 1 and new.count(NEW_LABEL) == 1 and
            OLD_LABEL not in new and new.replace(NEW_LABEL, OLD_LABEL, 1) == old,
            'API index differs beyond the upstream filter label')
    require(a['api/gnatdoc-navigation.js'] == NAVIGATION[BASELINE_VERSION] and
            b['api/gnatdoc-navigation.js'] == NAVIGATION[CANDIDATE_VERSION],
            'navigation runtime is not the exact tagged release asset')
    ma = json.loads((baseline / 'api/presentation.json').read_text(encoding='utf-8'))
    mb = json.loads((candidate / 'api/presentation.json').read_text(encoding='utf-8'))
    require(set(ma) == set(mb) and
            {k for k in ma if ma[k] != mb[k]} == {'enhancer_version', 'output_sha256'} and
            ma['enhancer_version'] == BASELINE_VERSION and mb['enhancer_version'] == CANDIDATE_VERSION,
            'presentation receipt differs beyond version-bound fields')
    require(set(ma['output_sha256']) == set(mb['output_sha256']) and
            {k for k in ma['output_sha256'] if ma['output_sha256'][k] != mb['output_sha256'][k]} ==
            {'api/index.html', 'api/gnatdoc-navigation.js'} and
            all(ma['output_sha256'][k] == a[k] and mb['output_sha256'][k] == b[k]
                for k in ma['output_sha256']),
            'presentation receipt output hashes differ from actual changed files')
    report = {
        'baseline_enhancer': BASELINE_VERSION, 'candidate_enhancer': CANDIDATE_VERSION,
        'files': len(a), 'identical_files': sorted(n for n in a if a[n] == b[n]),
        'changed_files': {n: {'baseline_sha256': a[n], 'candidate_sha256': b[n], **CHANGED[n]}
                          for n in differing},
        'baseline_sha256': a, 'candidate_sha256': b,
        'api_package_pages_identical': all(a[n] == b[n] for n in a
                                           if n.startswith('api/') and n.endswith('.html')
                                           and n != 'api/index.html'),
        'authored_pages_identical': all(a[n] == b[n] for n in a if not n.startswith('api/'))}
    require(report['api_package_pages_identical'] and report['authored_pages_identical'],
            'declaration or authored publication changed')
    if baseline_native is not None:
        require(hashes(baseline_native) == hashes(candidate_native),
                'publications were not generated from identical native GNATdoc input')
        report['native_input_sha256'] = hashes(candidate_native)
    return report


def baseline_site(native: Path, candidate: Path, environment: Path, workspace: Path):
    """Reconstruct the v0.1.1 API with the v0.1.1-qualified installer."""
    from qualify_shared_production import source_workspace
    tools = workspace / 'baseline-installer'
    tools.mkdir()
    installer = tools / 'install_released_gnatdoc.py'
    installer.write_bytes(subprocess.run(
        ['git', 'show', BASELINE_COMMIT + ':scripts/install_released_gnatdoc.py'],
        cwd=ROOT, check=True, capture_output=True).stdout)
    if not environment.exists():
        subprocess.run([sys.executable, '-I', str(installer), '--venv', str(environment)],
                       check=True, stdout=subprocess.DEVNULL)
    identity = json.loads(subprocess.run([sys.executable, '-I', str(installer), '--venv',
                                          str(environment), '--verify'],
                                         check=True, capture_output=True).stdout)
    require(identity['version'] == BASELINE_VERSION, 'baseline is not the qualified v0.1.1')
    source = source_workspace(ROOT, workspace / 'source')
    staged = workspace / 'baseline-api'
    shutil.copytree(native, staged)
    for command in ('inventory', 'enhance', 'verify'):
        subprocess.run([str(environment / 'bin/gnatdoc-enhancer'), command, '--config',
                        'candidate.toml', '--source-root', str(source), '--site', str(staged)],
                       check=True, timeout=180, stdout=subprocess.DEVNULL)
    site = workspace / 'baseline-site'
    shutil.copytree(candidate, site)
    shutil.rmtree(site / 'api')
    shutil.copytree(staged / 'api', site / 'api')
    return site, identity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--baseline-site', type=Path)
    group.add_argument('--baseline-venv', type=Path)
    parser.add_argument('--baseline-native', type=Path)
    parser.add_argument('--native', type=Path, help='candidate native GNATdoc input')
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--keep-baseline', type=Path,
                        help='retain the reconstructed baseline publication (new directory)')
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    if args.baseline_site:
        require((args.baseline_native is None) == (args.native is None),
                'native comparison needs both native inputs')
        report = compare(args.baseline_site.resolve(), candidate,
                         args.baseline_native and args.baseline_native.resolve(),
                         args.native and args.native.resolve())
        report['mode'] = 'two complete independent publications'
    else:
        require(args.native is not None and args.baseline_native is None,
                '--baseline-venv reconstructs from --native only')
        with tempfile.TemporaryDirectory(prefix='imgproc012-baseline-') as tmp:
            site, identity = baseline_site(args.native.resolve(), candidate,
                                           args.baseline_venv.absolute(), Path(tmp))
            report = compare(site, candidate)
            if args.keep_baseline:
                require(not args.keep_baseline.exists(), 'baseline retention path must be new')
                shutil.copytree(site, args.keep_baseline)
        report['mode'] = 'v0.1.1 API reconstructed from the same native input'
        report['baseline_installation'] = {k: identity[k] for k in (
            'version', 'tag_object', 'source_commit', 'source_tree', 'wheel_sha256')}
    write(args.report, report)
    print(f"Enhancer upgrade differential passed: {report['files']} files, "
          f"{len(report['changed_files'])} justified changes")


if __name__ == '__main__':
    main()
