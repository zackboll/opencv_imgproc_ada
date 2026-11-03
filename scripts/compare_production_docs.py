#!/usr/bin/env python3
"""Every-file legacy/shared classification with independent source/native checks."""
import argparse
import json
from pathlib import Path

from install_released_gnatdoc import require
from qualify_released_gnatdoc import hashes, write
from qualify_shared_production import final_semantics


def compare(native, legacy, shared, core):
    qualification = final_semantics(shared, native, core)
    old, new = hashes(legacy), hashes(shared)
    differences = {}
    package = next(p for p in old if p.startswith('api/') and len(Path(p).stem) == 64)
    classes = {
        package: 'Source/native preserved; direct-fragment Core URLs with _top; two source-proven local additions; title and lexical presentation',
        'api/index.html': 'Source-order identical 329 operations; released package/search/category navigation and document metadata',
        'api/gnatdoc-theme.css': 'Released light/dark API theme; authored focus/layout retained in consumer stylesheet',
        'api/gnatdoc-navigation.js': 'Released navigation implementation; independent exhaustive browser gate required',
        'api/presentation.json': 'Version-bound API-only receipt; pristine originals independently compared, never authorization',
        'api/type-crossrefs.json': 'Legacy implementation receipt retired; complete source-owned occurrence oracle retained outside publication',
    }
    for name in sorted(old.keys() | new.keys()):
        if old.get(name) == new.get(name):
            classification = 'byte-identical'
        else:
            require(name in classes, 'OUTPUT_PARITY_BLOCKED: unclassified publication difference: ' + name)
            classification = classes[name]
        differences[name] = {'legacy_sha256': old.get(name), 'shared_sha256': new.get(name),
                             'classification': classification}
    return {'files': differences, 'native_semantics': qualification,
            'authored_byte_identical': all(old[n] == new[n] for n in old
                                          if not n.startswith('api/')),
            'policy_approved': False, 'browser_qualification_is_separate': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('native', 'legacy', 'shared', 'core', 'report'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    write(args.report, compare(args.native.resolve(), args.legacy.resolve(), args.shared.resolve(), args.core.resolve()))