#!/usr/bin/env python3
"""Negative controls: only the three source-justified v0.1.5 changes are accepted."""
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from compare_enhancer_upgrade import NEW_LABEL, OLD_LABEL, compare

ROOT = Path(__file__).resolve().parents[1]
BASELINE = os.environ.get('DOC_BASELINE_SITE')


@unittest.skipUnless(BASELINE and (ROOT / '_site/api/presentation.json').is_file(),
                     'requires v0.1.1 baseline and generated v0.1.5 publication')
class UpgradeDifferential(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.baseline = Path(self.temporary.name) / 'baseline'
        self.candidate = Path(self.temporary.name) / 'candidate'
        shutil.copytree(BASELINE, self.baseline)
        shutil.copytree(ROOT / '_site', self.candidate)
        self.page = next(p.relative_to(self.candidate).as_posix()
                         for p in (self.candidate / 'api').glob('*.html') if p.name != 'index.html')

    def tearDown(self):
        self.temporary.cleanup()

    def test_accepts_exact_justified_changes(self):
        report = compare(self.baseline, self.candidate)
        self.assertEqual(sorted(report['changed_files']),
                         ['api/gnatdoc-navigation.js', 'api/index.html', 'api/presentation.json'])
        self.assertEqual(len(report['identical_files']), 11)

    def rejects(self, site, name, change):
        path = site / name
        original = path.read_bytes()
        path.write_bytes(change(original))
        try:
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                compare(self.baseline, self.candidate)
        finally:
            path.write_bytes(original)

    def test_byte_mutations_rejected(self):
        new, old = NEW_LABEL.encode(), OLD_LABEL.encode()
        cases = [
            (self.candidate, 'index.html', lambda b: b + b'\n'),
            (self.candidate, 'guides/filtering-and-transforms.html', lambda b: b.replace(b'<h1', b'<h1 hidden', 1)),
            (self.candidate, 'guides/gnatdoc-guides.css', lambda b: b + b'/* */'),
            (self.candidate, self.page, lambda b: b.replace(b'target="_top"', b'target="_self"', 1)),
            (self.candidate, 'api/gnatdoc.css', lambda b: b + b'\n'),
            (self.candidate, 'api/gnatdoc-theme.css', lambda b: b + b'\n'),
            (self.candidate, 'api/index.html', lambda b: b.replace(new, old)),
            (self.candidate, 'api/index.html', lambda b: b.replace(new, new + b'<script>x</script>')),
            (self.candidate, 'api/index.html', lambda b: b.replace(b'target=document-content', b'target=_top', 1)),
            (self.candidate, 'api/gnatdoc-navigation.js', lambda b: b + b'\n'),
            (self.baseline, 'api/gnatdoc-navigation.js', lambda b: b + b'\n'),
            (self.baseline, 'api/index.html', lambda b: b.replace(old, new)),
        ]
        for site, name, change in cases:
            with self.subTest(site=site.name, name=name):
                self.rejects(site, name, change)

    def test_receipt_mutations_rejected(self):
        def edit(mutate):
            def change(data):
                record = json.loads(data)
                mutate(record)
                return json.dumps(record).encode()
            return change
        mutations = [
            lambda r: r.__setitem__('enhancer_version', '0.1.4'),
            lambda r: r['counts'].__setitem__('linked_external_types', 585),
            lambda r: r['output_sha256'].__setitem__('api/index.html', '0' * 64),
            lambda r: r['output_sha256'].__setitem__('api/gnatdoc-theme.css', '0' * 64),
            lambda r: r.__setitem__('extra', True),
            lambda r: r['original_api_html'].__setitem__('api/index.html', ''),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.rejects(self.candidate, 'api/presentation.json', edit(mutate))

    def test_inventory_and_native_mutations_rejected(self):
        (self.candidate / 'api/extra.js').write_text('')
        with self.assertRaisesRegex(ValueError, 'inventories'):
            compare(self.baseline, self.candidate)
        (self.candidate / 'api/extra.js').unlink()
        native = Path(self.temporary.name) / 'native'
        other = Path(self.temporary.name) / 'native-other'
        for directory, text in ((native, 'a'), (other, 'b')):
            (directory / 'api').mkdir(parents=True)
            (directory / 'api/index.html').write_text(text)
        with self.assertRaisesRegex(ValueError, 'identical native'):
            compare(self.baseline, self.candidate, native, other)


if __name__ == '__main__':
    unittest.main()
