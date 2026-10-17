"""Small runner boundary tests; full-site tampering is a separate command."""
from pathlib import Path
import tempfile
import unittest

from qualify_shared_gnatdoc_shadow import CORE, check_files, dependency, digest, hashes, read_json, trusted_inputs


class ShadowBoundaries(unittest.TestCase):
    def test_checked_in_authority_matches(self):
        trusted_inputs()

    def test_duplicate_authority_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "authority.json"
            path.write_text('{"a": 1, "a": 2}')
            self.assertEqual(path.read_text().count('"a"'), 2)
            with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                read_json(path)

    def test_changed_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "source.ads"
            path.write_bytes(b"original")
            expected = {"source.ads": digest(path.read_bytes())}
            check_files(root, expected)
            path.write_bytes(b"changed")
            self.assertNotEqual(digest(path.read_bytes()), expected["source.ads"])
            with self.assertRaisesRegex(ValueError, "authority mismatch"):
                check_files(root, expected)

    def test_symlink_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "source").mkdir()
            (root / "alias").symlink_to(root / "source", target_is_directory=True)
            self.assertTrue((root / "alias").is_symlink())
            with self.assertRaisesRegex(ValueError, "symlink"):
                hashes(root)

    def test_origin_and_version_must_both_match(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "alire.lock"
            original = ('[solution]\n[[solution.state]]\ncrate = "opencv_core"\npinned = false\n'
                        '[solution.state.release]\nversion = "0.4.1"\n[solution.state.release.origin]\n'
                        f'commit = "{CORE}"\n'
                        'url = "git+https://github.com/zackboll/opencv_core_ada.git"\n')
            path.write_text(original)
            self.assertEqual(dependency(path)["version"], "0.4.1")
            for old, new in ((CORE, "0" * 40), ('"0.4.1"', '"0.5.0"'),
                             ("pinned = false", "pinned = true")):
                path.write_text(original.replace(old, new))
                self.assertNotEqual(path.read_text(), original)
                with self.assertRaisesRegex(ValueError, "unqualified Core"):
                    dependency(path)


if __name__ == "__main__":
    unittest.main()