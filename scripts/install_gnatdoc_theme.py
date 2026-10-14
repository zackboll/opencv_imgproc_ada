#!/usr/bin/env python3
"""Install narrowly approved metadata and verify native non-snippet HTML."""

import argparse
import hashlib
import json
from pathlib import Path

from link_gnatdoc_types import SECTION, require


NATIVE = '<link rel=stylesheet href=gnatdoc.css>'
METADATA = ('<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<link rel="stylesheet" href="gnatdoc-theme.css">')
ASSET = Path(__file__).resolve().parent.parent / 'docs/assets/gnatdoc-theme.css'


def skeleton(text):
    return SECTION.sub(lambda m: m[0][:m.start(3) - m.start()] +
                       m[0][m.end(3) - m.start():], text)


def themed(text):
    require(text.count(NATIVE) == 1, 'unexpected native stylesheet insertion point')
    require('gnatdoc-theme.css' not in text and '<meta name="viewport"' not in text,
            'unexpected native theme/viewport metadata')
    return text.replace(NATIVE, NATIVE + METADATA, 1)


def check_theme(api):
    manifest_path = api / 'presentation.json'
    require(manifest_path.is_file(), 'missing presentation integrity manifest')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    require(manifest.get('version') == 1, 'unexpected presentation contract version')
    paths = {p.name: p for p in api.glob('*.html')}
    require(set(paths) == set(manifest['pages']), 'presentation page coverage mismatch')
    require((api / 'gnatdoc-theme.css').is_file(), 'missing theme asset')
    require((api / 'gnatdoc-theme.css').read_bytes() == ASSET.read_bytes(),
            'theme asset differs from repository stylesheet')
    require(hashlib.sha256((api / 'gnatdoc.css').read_bytes()).hexdigest() == manifest['native_css'],
            'native GNATdoc stylesheet changed')
    for name, path in paths.items():
        expected = themed(manifest['pages'][name])
        if name == 'index.html' and (api / 'gnatdoc-navigation.js').exists():
            from enhance_gnatdoc_navigation import augmented, check_navigation
            check_navigation(api)
            expected = augmented(expected, api)
        require(skeleton(path.read_text(encoding='utf-8')) == expected,
                f'unapproved non-snippet presentation change: {name}')
    print(f'Theme: {len(paths)} API pages verified; asset/metadata errors: 0')


def install(api):
    if (api / 'presentation.json').exists():
        check_theme(api)
        return
    require(not (api / 'type-crossrefs.json').exists(), 'install theme before type linking')
    require(ASSET.is_file() and ASSET.stat().st_size, 'missing repository theme asset')
    paths = sorted(api.glob('*.html'))
    require(paths and (api / 'index.html').is_file(), 'missing native API pages')
    original = {p.name: skeleton(p.read_text(encoding='utf-8')) for p in paths}
    results = {p: themed(p.read_text(encoding='utf-8')) for p in paths}
    manifest = {'version': 1, 'pages': original,
                'native_css': hashlib.sha256((api / 'gnatdoc.css').read_bytes()).hexdigest()}
    for path, text in results.items():
        path.write_text(text, encoding='utf-8')
    (api / 'gnatdoc-theme.css').write_bytes(ASSET.read_bytes())
    (api / 'presentation.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n',
                                          encoding='utf-8')
    check_theme(api)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('api', type=Path)
    args = parser.parse_args()
    install(args.api)