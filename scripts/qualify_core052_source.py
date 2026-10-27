#!/usr/bin/env python3
"""Independently construct R3 Core source/native authority from immutable Git.

This is an explicit qualification command, never a production auto-approval.
The old source authority stays historical. New source bytes are compared, not
assumed identical; referenced complete declarations must remain exact.
"""
import argparse
import difflib
import json
from pathlib import Path
import tomllib

from install_released_gnatdoc import digest, require
from qualify_production_core_links import git, public_model, source_native_types
from qualify_released_gnatdoc import hashes, write

OLD = 'f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f'
NEW = 'aa8a378ab614e9a5fc4f43765cd3ff1bbcf6a44d'
TREE = '3340347a8cd3945c36e9ecde9e4a4798efbd91f7'
INDEX = '842d7165e3e1e644f4d03563e7a4f35c05415af4'
ROOT = Path(__file__).resolve().parents[1]


def inventory(repository, revision):
    names = git(repository, 'ls-tree', '-r', '--name-only', revision, '--', 'src').decode().splitlines()
    return {name: git(repository, 'show', revision + ':' + name) for name in names}


def qualify(args):
    require(not args.output.exists(), 'qualification output must be new')
    args.output.mkdir(parents=True)
    require(git(args.core, 'rev-parse', 'HEAD').decode().strip() == NEW and
            git(args.core, 'rev-parse', 'HEAD^{tree}').decode().strip() == TREE and
            not git(args.core, 'diff', '--name-only', 'HEAD', '--', 'src'), 'wrong or changed Core checkout')
    manifest_name = 'index/op/opencv_core/opencv_core-0.5.2.toml'
    require(git(args.index, 'rev-parse', 'HEAD').decode().strip() == INDEX and
            not git(args.index, 'status', '--porcelain'), 'unreviewed or dirty index snapshot')
    release = git(args.index, 'show', INDEX + ':' + manifest_name)
    require((args.index / manifest_name).read_bytes() == release, 'index member substitution')
    metadata = tomllib.loads(release.decode())
    require(metadata['version'] == '0.5.2' and metadata['origin'] == {
        'commit': NEW, 'url': 'git+https://github.com/zackboll/opencv_core_ada.git'}, 'wrong indexed origin')
    (args.output / 'indexed-release.toml').write_bytes(release)
    before, after = inventory(args.core, OLD), inventory(args.core, NEW)
    require({k: digest(v) for k, v in after.items()} == {
        p.relative_to(args.core).as_posix(): digest(p.read_bytes())
        for p in (args.core / 'src').rglob('*') if p.is_file()}, 'Git/source inventory mismatch')
    changes = {}
    for name in sorted(before.keys() | after.keys()):
        a, b = before.get(name), after.get(name)
        classification = 'identical' if a == b else 'changed'
        entry = {'before_sha256': digest(a) if a is not None else None,
                 'after_sha256': digest(b) if b is not None else None,
                 'classification': classification}
        if a != b:
            entry['unified_diff'] = ''.join(difflib.unified_diff(
                (a or b'').decode().splitlines(keepends=True),
                (b or b'').decode().splitlines(keepends=True),
                fromfile=OLD + '/' + name, tofile=NEW + '/' + name))
        changes[name] = entry
    historical = json.loads((ROOT / 'docs/evidence/gnatdoc009/r1/core-destination-proposal.json').read_text())
    proofs = source_native_types(args.core, args.native, historical['types'])
    comparisons = {}
    for identity, new in proofs.items():
        old = historical['types'][identity]
        fields = ('identity', 'owner', 'kind', 'source_declaration_text',
                  'source_declaration_sha256', 'native_anchor', 'native_page', 'native_snippet')
        require(all(new[k] == old[k] for k in fields) and
                new['declaration']['signature'] == old['declaration']['signature'],
                'REFERENCED_DECLARATION_CHANGED: ' + identity)
        comparisons[identity] = {'before': old, 'after': new,
                                 'complete_declaration_and_native_identity_equal': True}
    public_changes = {}
    for name in sorted(n for n in changes if n.startswith('src/') and
                       '/' not in n[4:] and n.endswith('.ads') and before.get(n) != after.get(n)):
        model = public_model(args.core / name)
        # Construct the old model from the independently fetched Git bytes.
        old_file = args.output / ('old-' + Path(name).name)
        old_file.write_bytes(before[name])
        old_model = public_model(old_file)
        a = [d['signature'] for d in old_model.top]
        b = [d['signature'] for d in model.top]
        from collections import Counter
        added = list((Counter(b) - Counter(a)).elements())
        removed = list((Counter(a) - Counter(b)).elements())
        require(not removed, 'existing public declaration removed or changed')
        public_changes[name] = {'added_complete_signatures': added, 'removed_signatures': removed,
                                'existing_public_profiles_preserved': True}
    write(args.output / 'source-delta.json', {'before': OLD, 'after': NEW,
          'files': changes, 'public_declaration_changes': public_changes})
    write(args.output / 'referenced-declarations.json', comparisons)
    write(args.output / 'source-authority.json', {
        'schema_version': 1, 'version': '0.5.2', 'origin': NEW, 'tree': TREE,
        'index_commit': INDEX, 'index_tree': git(args.index, 'rev-parse', 'HEAD^{tree}').decode().strip(),
        'index_manifest_path': manifest_name, 'index_manifest_git_blob': git(
            args.index, 'rev-parse', INDEX + ':' + manifest_name).decode().strip(),
        'release_manifest_sha256': digest(release), 'release_manifest': metadata,
        'source_sha256': {k: digest(v) for k, v in after.items()},
        'native_sha256': hashes(args.native), 'types': proofs,
        'historical_baseline': OLD, 'referenced_declarations_equal': True,
        'future_release_authorized': False,
    })


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('core', 'native', 'index', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    qualify(parser.parse_args())