"""R3 source authorization mutations; no version range or receipt can approve bytes."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import tomllib
import unittest

import core_source_authority as core


class SourceAuthority(unittest.TestCase):
    def setUp(self):
        self.authority = core.authority()
        self.manifest = tomllib.loads((core.ROOT / 'alire.toml').read_text())
        self.state = {'crate': 'opencv_core', 'fulfilment': 'solved', 'pinned': False,
                      'versions': '~0.5.0', 'release': {'version': '0.5.2', 'origin': {
                          'commit': core.ORIGIN, 'url': 'git+https://github.com/zackboll/opencv_core_ada.git'}}}

    def lock(self, state=None):
        return {'solution': {'state': [state or self.state]}}

    def test_exact_unpinned_release_only(self):
        self.assertEqual(core.check_solution(self.lock(), self.manifest), self.state)
        for version in ('0.5.0', '0.5.1', '0.5.3', '0.5.99', '0.6.0'):
            changed = copy.deepcopy(self.state)
            changed['release']['version'] = version
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'SOURCE_AUTHORITY_CHANGED'):
                core.check_solution(self.lock(changed), self.manifest)

    def test_wrong_origin_or_pin_even_with_right_version(self):
        for field, value in (('commit', '0' * 40), ('url', 'git+https://evil.invalid/core.git')):
            changed = copy.deepcopy(self.state)
            changed['release']['origin'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                core.check_solution(self.lock(changed), self.manifest)
        changed = copy.deepcopy(self.state)
        changed['pinned'] = True
        with self.assertRaises(ValueError):
            core.check_solution(self.lock(changed), self.manifest)
        manifest = copy.deepcopy(self.manifest)
        manifest['pins'] = [{'opencv_core': {'path': '../core'}}]
        with self.assertRaises(ValueError):
            core.check_solution(self.lock(), manifest)

    def test_duplicate_selection_rejected(self):
        lock = self.lock()
        lock['solution']['state'].append(copy.deepcopy(self.state))
        with self.assertRaises(ValueError):
            core.check_solution(lock, self.manifest)

    def test_complete_source_inventory_substitution_and_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'src').mkdir()
            path = root / 'src/opencv.ads'
            path.write_text('package OpenCV is end OpenCV;')
            with self.assertRaisesRegex(ValueError, 'source inventory'):
                core.check_source(root, self.authority)
            path.unlink()
            path.symlink_to(core.ROOT / 'src/opencv-image_processing.ads')
            with self.assertRaisesRegex(ValueError, 'unsafe Core'):
                core.check_source(root, self.authority)

    def test_forged_authority_and_release_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'docs/evidence/gnatdoc009/r3'
            folder.mkdir(parents=True)
            shutil.copyfile(core.ROOT / folder.relative_to(root) / 'source-authority.json', folder / 'source-authority.json')
            shutil.copyfile(core.ROOT / folder.relative_to(root) / 'indexed-release.toml', folder / 'indexed-release.toml')
            core.authority(root)
            (folder / 'indexed-release.toml').write_text('version="0.5.2"')
            with self.assertRaisesRegex(ValueError, 'forged indexed'):
                core.authority(root)
            forged = copy.deepcopy(self.authority)
            forged['source_sha256']['src/opencv.ads'] = '0' * 64
            (folder / 'source-authority.json').write_text(json.dumps(forged))
            with self.assertRaisesRegex(ValueError, 'forged R3'):
                core.authority(root)

    def test_copied_lock_or_different_live_dependency_receipt(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'alire').mkdir()
            (root / 'alire/alire.lock').write_text('copied stale solution')
            (root / 'alire.toml').write_bytes((core.ROOT / 'alire.toml').read_bytes())
            (root / 'obj/docs').mkdir(parents=True)
            # Even after independently satisfying version/source checks, a
            # receipt copied from another root or live source must fail closed.
            (root / 'obj/docs/core-resolution.json').write_text(json.dumps({
                'root': '/other/checkout', 'source': '/other/core', 'version': '0.5.2'}))
            with patch.object(core, 'authority', return_value=self.authority), \
                    patch.object(core.tomllib, 'loads', return_value={}), \
                    patch.object(core, 'check_solution'), patch.object(core, 'check_source'):
                with self.assertRaisesRegex(ValueError, 'copied/stale'):
                    core.checked_resolution(root, root / 'resolved-core')


if __name__ == '__main__':
    unittest.main()