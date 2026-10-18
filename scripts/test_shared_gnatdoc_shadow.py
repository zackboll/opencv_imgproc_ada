"""Small runner boundary tests; full-site tampering is a separate command."""
from pathlib import Path
import shutil
import tempfile
import unittest

from qualify_shared_gnatdoc_shadow import (CORE, EVIDENCE, ROOT, TRANSITION, check_files,
    dependency, digest, hashes, read_json, trusted_inputs)
from compare_shared_gnatdoc_navigation import Links
from record_shared_gnatdoc_shadow import record


class ShadowBoundaries(unittest.TestCase):
    def test_checked_in_authority_matches(self):
        trusted_inputs()

    def test_navigation_audit_preserves_real_target_and_visible_label(self):
        links = Links('<a href="native.html#anchor" target=document-content>Filter_2D (17)</a>'
                      '<a href="native.html" target=document-content>Package</a>')
        self.assertEqual(links.links, [["native.html#anchor", "Filter_2D (17)"]])

    def test_transition_cannot_approve_changed_historical_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / EVIDENCE, root / EVIDENCE)
            (root / TRANSITION).parent.mkdir(parents=True)
            shutil.copyfile(ROOT / TRANSITION, root / TRANSITION)
            config = root / "docs/shared-gnatdoc-shadow.toml"
            shutil.copyfile(ROOT / "docs/shared-gnatdoc-shadow.toml", config)
            trusted_inputs(root)
            for path in (root / TRANSITION, root / EVIDENCE / "authority.json",
                         root / EVIDENCE / "core-types.json", config):
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                self.assertNotEqual(path.read_bytes(), original)
                with self.assertRaisesRegex(ValueError, "authority mismatch"):
                    trusted_inputs(root)
                path.write_bytes(original)
            (root / TRANSITION).unlink()
            with self.assertRaisesRegex(ValueError, "authority mismatch"):
                trusted_inputs(root)

    def test_readiness_fails_closed_without_current_run(self):
        with tempfile.TemporaryDirectory() as directory:
            result = record(Path(directory))
            self.assertFalse(result["full_shadow_qualification"])
            self.assertFalse(result["current_run_complete"])
            self.assertEqual(len(result["missing_evidence"]), 4)

    def test_historical_reports_cannot_qualify_new_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for old, current in (("local-qualification", "qualification"),
                                 ("adversarial", "negative"), ("navigation-comparison", "navigation-comparison"),
                                 ("browser-summary", "browser")):
                shutil.copyfile(ROOT / EVIDENCE / (old + ".json"), root / (current + ".json"))
            result = record(root)
            self.assertFalse(result["full_shadow_qualification"])
            self.assertFalse(result["current_run_complete"])

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