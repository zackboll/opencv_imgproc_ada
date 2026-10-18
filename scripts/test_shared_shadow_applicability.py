"""Applicability, isolation and fail-closed workflow controls (not site evidence)."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import shared_shadow_applicability as scope
from qualify_shared_gnatdoc_shadow import trusted_inputs, check_files, EVIDENCE


class ApplicabilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        scope.git(self.root, "init", "-q")
        scope.git(self.root, "config", "user.name", "Test")
        scope.git(self.root, "config", "user.email", "test@invalid")
        self.put("src/image.ads", "historical production\n")
        self.put("scripts/qualify_shared_gnatdoc_shadow.py", "historical integration\n")
        self.base = self.commit()

    def tearDown(self):
        self.temp.cleanup()

    def put(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)

    def commit(self):
        scope.git(self.root, "add", "--all")
        scope.git(self.root, "commit", "-qm", "test", "--allow-empty")
        return scope.git(self.root, "rev-parse", "HEAD").decode().strip()

    def test_api_feature_is_explicitly_not_applicable(self):
        self.put("src/image.ads", "new API\n")
        self.put("cpp/shim.cpp", "new implementation\n")
        report = scope.assess(self.root, self.base, self.commit())
        self.assertFalse(report["applicable"])
        self.assertEqual(report["disposition"], "NOT_APPLICABLE_API_FEATURE")
        self.assertFalse(report["historical_qualification_passed"])
        self.assertEqual(report["changed_paths"], ["cpp/shim.cpp", "src/image.ads"])

    def test_integration_and_api_changes_require_full_historical_run(self):
        self.put("src/image.ads", "new API\n")
        self.put("scripts/qualify_shared_gnatdoc_shadow.py", "changed integration\n")
        head = self.commit()
        report = scope.assess(self.root, self.base, head)
        self.assertTrue(report["applicable"])
        self.assertEqual(report["disposition"], "FULL_HISTORICAL_QUALIFICATION_REQUIRED")
        destination = Path(self.temp.name) / "historical"
        with patch.object(scope, "HISTORICAL", self.base):
            binding = scope.prepare(self.root, head, destination)
        self.assertEqual((destination / "src/image.ads").read_text(), "historical production\n")
        self.assertEqual((destination / "scripts/qualify_shared_gnatdoc_shadow.py").read_text(),
                         "changed integration\n")
        self.assertEqual(binding["pr_head"], head)
        self.assertEqual(binding["historical_consumer"], self.base)
        self.assertEqual(scope.git(destination, "rev-parse", "HEAD").decode().strip(),
                         binding["isolated_test_head"])
        self.assertEqual(scope.git(self.root, "rev-parse", "HEAD").decode().strip(), head)

    def test_deletion_or_rename_cannot_hide_integration_change(self):
        scope.git(self.root, "mv", "scripts/qualify_shared_gnatdoc_shadow.py", "ordinary.py")
        report = scope.assess(self.root, self.base, self.commit())
        self.assertTrue(report["applicable"])
        self.assertIn("scripts/qualify_shared_gnatdoc_shadow.py", report["integration_paths"])

    def test_authority_configuration_workflow_and_tools_are_in_scope(self):
        for name in ("docs/evidence/gnatdoc008/authority.json",
                     "docs/evidence/gnatdoc008c/authority-transition.json",
                     "docs/shared-gnatdoc-shadow.toml",
                     "docs/shared-gnatdoc-shadow-qualification.md",
                     "docs/shared-shadow-applicability.md",
                     ".github/workflows/documentation-shared-shadow.yml",
                     "scripts/qualify_shared_gnatdoc_browser.py",
                     "scripts/compare_shared_gnatdoc_navigation.py",
                     "scripts/record_shared_gnatdoc_shadow.py",
                     "scripts/collect_shared_gnatdoc_evidence.py",
                     "scripts/shared_shadow_applicability.py",
                     "scripts/test_shared_shadow_applicability.py"):
            with self.subTest(path=name):
                self.assertTrue(scope.integration_path(name))

    def test_bad_or_wrong_head_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "full immutable"):
            scope.assess(self.root, "HEAD", self.base)
        new = self.commit()
        with self.assertRaisesRegex(ValueError, "exact PR head"):
            scope.assess(self.root, new, self.base)

    def test_symlink_overlay_is_rejected(self):
        (self.root / "scripts/qualify_shared_gnatdoc_shadow.py").unlink()
        (self.root / "scripts/qualify_shared_gnatdoc_shadow.py").symlink_to("../src/image.ads")
        head = self.commit()
        with patch.object(scope, "HISTORICAL", self.base):
            with self.assertRaisesRegex(ValueError, "non-regular"):
                scope.prepare(self.root, head, Path(self.temp.name) / "historical")

    def test_real_frozen_authority_and_source_checks_are_not_rewritten(self):
        trusted_inputs()
        # Verify historical production bytes even though the live feature
        # source legitimately no longer matches that immutable inventory.
        manifest = json.loads((scope.ROOT / EVIDENCE / "consumer-input.json").read_text())
        for name, digest in manifest["source_sha256"].items():
            data = scope.git(scope.ROOT, "show", scope.HISTORICAL + ":" + name)
            self.assertEqual(scope.hashlib.sha256(data).hexdigest(), digest, name)
        # Exercise rejection without assuming whether the calling checkout is
        # a new API feature or the isolated historical consumer itself.
        self.put("src/image.ads", "tampered\n")
        with self.assertRaisesRegex(ValueError, "authority mismatch"):
            check_files(self.root, {"src/image.ads": "0" * 64})
        frozen = scope.git(scope.ROOT, "show", scope.HISTORICAL +
                           ":scripts/qualify_shared_gnatdoc_shadow.py")
        self.assertEqual(frozen, (scope.ROOT / "scripts/qualify_shared_gnatdoc_shadow.py").read_bytes())

    def test_workflow_always_reports_and_requires_generated_evidence(self):
        workflow = (scope.ROOT / ".github/workflows/documentation-shared-shadow.yml").read_text()
        self.assertNotIn("paths:", workflow)
        self.assertNotIn("paths-ignore:", workflow)
        self.assertIn("  pull_request:", workflow)
        self.assertIn("shadow-applicability.json", workflow)
        self.assertIn("shadow-source-binding.json", workflow)
        for outcome in ("qualification", "adversarial", "browser", "parity"):
            self.assertIn(f"if: success() && steps.{outcome}.outcome == 'success'", workflow)
        self.assertNotIn("success() || failure()", workflow)
        self.assertNotIn("continue-on-error", workflow)
        self.assertIn("historical/scripts/qualify_shared_gnatdoc_shadow.py", workflow)
        regular = (scope.ROOT / ".github/workflows/documentation.yml").read_text()
        self.assertIn("  pull_request:", regular)
        self.assertNotIn("paths-ignore:", regular)
        self.assertIn("run: sh scripts/generate_docs.sh", regular)


if __name__ == "__main__":
    unittest.main()