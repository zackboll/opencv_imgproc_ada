"""Source/native/full-site mutations, not toolkit-manifest self-authorization."""
import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

from link_gnatdoc_types import CORE_ROOT
from qualify_shared_production import ROOT, final_semantics


@unittest.skipUnless((ROOT / 'obj/docs/native/api/index.html').is_file(), 'requires authentic native generation')
class ProductionMutations(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / 'site'
        shutil.copytree(ROOT / '_site', self.site)
        self.native = ROOT / 'obj/docs/native'
        self.page = next(p for p in (self.site / 'api').glob('*.html') if p.name != 'index.html')

    def tearDown(self):
        self.temporary.cleanup()

    def check(self):
        return final_semantics(self.site, self.native, CORE_ROOT)

    def test_complete_site(self):
        result = self.check()
        self.assertEqual(result['core_occurrences'], 586)
        self.assertEqual(result['local_occurrences'], 350)
        self.assertEqual(result['documented_elements'], 1596)
        self.assertEqual(result['authored_example_links'], 55)

    def test_wrong_existing_core_local_anchor_profile_marks_targets_and_scripts(self):
        original = self.page.read_text()
        core_links = re.findall(r'href="(https:[^"]+)"', original)
        local_links = re.findall(r'href="([^"#]+\.html#[^"]+)"', original)
        changes = [
            (core_links[0], next(x for x in core_links if x != core_links[0])),
            (local_links[0], next(x for x in local_links if x != local_links[0])),
            ('Source_2', 'Substituted_Source'),
            ('data-type="opencv.core.mat"', 'data-type="opencv.size"'),
            ('target="_top"', 'target="_self"'),
            ('target="_top"', 'target="_blank"'),
            ('<h1>', '<script src="evil.js"></script><h1>'),
            ('<h1>', '<h1 id="duplicate"><i id="duplicate"></i>'),
            ('<h1>', '<h1 hidden>'),
            ('class="ada-keyword"', 'class="ada-keyword" onclick="alert(1)"'),
            ('href="https:', 'href="javascript:'),
        ]
        for before, after in changes:
            with self.subTest(before=before):
                self.assertIn(before, original)
                self.page.write_text(original.replace(before, after, 1))
                with self.assertRaises(ValueError):
                    self.check()
                self.page.write_text(original)

    def test_guides_assets_and_receipts_cannot_authorize_mutations(self):
        for name in ('index.html', 'guides/filtering-and-transforms.html',
                     'guides/gnatdoc-guides.css', 'guides/gnatdoc-authored.css',
                     'api/gnatdoc-theme.css', 'api/gnatdoc-navigation.js',
                     'api/presentation.json'):
            path = self.site / name
            original = path.read_bytes()
            with self.subTest(name=name):
                path.write_bytes(original + b'\nTAMPERED\n')
                with self.assertRaises((ValueError, json.JSONDecodeError)):
                    self.check()
                path.write_bytes(original)

    def test_manifest_native_substitution_rejected(self):
        path = self.site / 'api/presentation.json'
        record = json.loads(path.read_text())
        name = next(x for x in record['original_api_html'] if x != 'api/index.html')
        record['original_api_html'][name] = record['original_api_html'][name].replace('Source_2', 'Source_3')
        path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'pristine native authority'):
            self.check()


if __name__ == '__main__':
    unittest.main()