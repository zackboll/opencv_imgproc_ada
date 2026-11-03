#!/usr/bin/env python3
"""Independent R1 ledger and security mutation controls."""
import copy
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from probe_core_candidate import SnippetLinks, reconcile
from qualify_production_core_links import NoRedirect, fetch


class CoreSecurity(unittest.TestCase):
    def test_decoded_snippet_offsets_survive_highlighting(self):
        raw = ('<span class="ada-keyword">function</span> F (X : '
               '<a class="type-reference" href="https://zackboll.github.io/x#y" '
               'data-type="opencv.core.mat">OpenCV.Core.Mat</a>; Y : '
               '<a class="type-reference" href="https://zackboll.github.io/x#z" '
               'data-type="opencv.size">OpenCV.Size</a>)')
        links = SnippetLinks(raw)
        for link in links.links:
            self.assertEqual(links.text[link['start']:link['end']], link['label'])
        self.assertGreater(links.links[1]['start'], links.links[0]['end'])

    def test_redirect_rejected(self):
        for url in ('https://evil.invalid/', 'https://zackboll.github.io/other.html'):
            with self.subTest(url=url), self.assertRaisesRegex(ValueError, 'redirect rejected'):
                NoRedirect().redirect_request(None, None, 302, '', {}, url)

    def test_unsafe_fetch_path_never_reaches_network(self):
        for name in ('../secret', 'api/../../secret', '/api/x.html', 'https://evil.invalid/',
                     'api/x.exe', 'api/x.html?redirect=evil', 'api/x.html#invented'):
            with self.subTest(name=name), patch('urllib.request.build_opener') as opener:
                with self.assertRaises(ValueError):
                    fetch(name)
                opener.assert_not_called()

    def test_nested_type_link_rejected(self):
        with self.assertRaisesRegex(ValueError, 'nested'):
            SnippetLinks('<a href="x"><a href="y">Mat</a></a>')


@unittest.skipUnless(os.environ.get('CORE_R1_WORKSPACE'), 'requires reconstructed R1 candidate')
class FullCensusMutations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = Path(os.environ['CORE_R1_WORKSPACE'])
        cls.proposal = json.loads((cls.work / 'proposal-complete/core-destination-proposal.json').read_text())
        cls.native = Path(os.environ['CORE_R1_NATIVE'])
        cls.candidate = cls.work / 'candidate-verified/first'

    def test_complete_identity_offset_url_census(self):
        result = reconcile(self.native, self.candidate, self.proposal)
        self.assertEqual(result['core_occurrences'], 586)
        self.assertEqual(result['core_distinct_types'], 14)
        self.assertEqual(result['local_occurrences'], 350)

    def test_count_cannot_authorize_wrong_url_owner_offset_or_duplicate(self):
        for field, value in [('proposed_url', 'https://evil.invalid/#invented'),
                             ('core_identity', 'opencv.wrong.mat'),
                             ('type_mark_start', -1), ('type_mark', 'Wrong_Type')]:
            with self.subTest(field=field):
                mutated = copy.deepcopy(self.proposal)
                mutated['occurrences'][0][field] = value
                with self.assertRaises(ValueError):
                    reconcile(self.native, self.candidate, mutated)
        mutated = copy.deepcopy(self.proposal)
        mutated['occurrences'][0] = mutated['occurrences'][1]
        with self.assertRaises(ValueError):
            reconcile(self.native, self.candidate, mutated)

    def test_changed_candidate_anchor_source_and_link_identity_rejected(self):
        occurrence = self.proposal['occurrences'][0]
        relative = occurrence['native_page']
        original = (self.candidate / relative).read_text()
        changes = [
            (occurrence['proposed_url'], occurrence['proposed_url'].split('#')[0] + '#' + '0' * 64),
            ('data-type="' + occurrence['core_identity'] + '"', 'data-type="opencv.wrong.type"'),
            ('<h4 id=' + occurrence['native_anchor'] + '>', '<h4 id=' + '0' * 64 + '>'),
            ('<span class="ada-keyword">function</span>', '<span class="ada-keyword">procedure</span>')]
        for before, after in changes:
            with self.subTest(before=before), tempfile.TemporaryDirectory() as tmp:
                candidate = Path(tmp) / 'site'
                shutil.copytree(self.candidate, candidate)
                self.assertIn(before, original)
                (candidate / relative).write_text(original.replace(before, after, 1))
                with self.assertRaises(ValueError):
                    reconcile(self.native, candidate, self.proposal)


if __name__ == '__main__':
    unittest.main()