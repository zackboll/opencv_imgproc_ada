#!/usr/bin/env python3
"""Negative controls for the Imgproc-owned release installer and oracle."""
from pathlib import Path
import os
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import install_released_gnatdoc as install
from qualify_released_gnatdoc import Operations


class ReleaseSecurity(unittest.TestCase):
    def test_unapproved_urls(self):
        for url in ("http://github.com/release", "https://evil.invalid/x",
                    "https://github.com.evil.invalid/x", "https://user@github.com/x",
                    "https://github.com:8443/x", "file:///tmp/tool.whl"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                install.approved_url(url)

    def test_approved_hosts_only(self):
        install.approved_url("https://github.com/a/b/releases/download/v0.1.0/tool.whl")
        install.approved_url("https://release-assets.githubusercontent.com/x")

    def test_redirect_is_checked_before_following(self):
        with self.assertRaises(ValueError):
            install.Redirect().redirect_request(None, None, 302, "", {},
                                                "https://evil.invalid/wheel")

    def test_incomplete_oversized_and_bad_downloads_rejected(self):
        from unittest.mock import MagicMock
        for data, size, sha in ((b"short", 8, install.digest(b"short")),
                                (b"oversized", 8, install.digest(b"oversized")),
                                (b"altered!", 8, "0" * 64)):
            with self.subTest(data=data), tempfile.TemporaryDirectory() as tmp:
                response = MagicMock()
                response.__enter__.return_value = response
                response.url = "https://github.com/a/b"
                response.status = 200
                response.headers = {}
                response.read.return_value = data
                opener = MagicMock()
                opener.open.return_value = response
                target = Path(tmp) / "download.whl"
                with patch.object(install.urllib.request, "build_opener", return_value=opener):
                    with self.assertRaises(ValueError):
                        install.download("archive.whl", target, sha, size)
                self.assertFalse(target.exists())

    def test_duplicate_and_symlink_members_rejected(self):
        import warnings
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.whl"
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(path, "w") as z:
                    z.writestr("same.py", b"one")
                    z.writestr("same.py", b"two")
            with self.assertRaisesRegex(ValueError, "duplicate"):
                install.archive(path, install.digest(path.read_bytes()))
            with zipfile.ZipFile(path, "w") as z:
                item = zipfile.ZipInfo("link.py")
                item.create_system = 3
                item.external_attr = (0o120777 << 16)
                z.writestr(item, "../outside")
            with self.assertRaisesRegex(ValueError, "unsafe wheel"):
                install.archive(path, install.digest(path.read_bytes()))

    def test_bad_hash_and_member_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample.whl"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("expected.py", b"original")
            sha = install.digest(path.read_bytes())
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                install.archive(path, "0" * 64)
            with self.assertRaisesRegex(ValueError, "member inventory"):
                install.archive(path, sha, {"other.py"})
            self.assertEqual(install.archive(path, sha, {"expected.py"}),
                             {"expected.py": b"original"})

    def test_unsafe_archive_paths(self):
        for name in ("../escape.py", "/absolute.py"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / "unsafe.whl"
                with zipfile.ZipFile(path, "w") as z:
                    z.writestr(name, b"data")
                with self.assertRaisesRegex(ValueError, "unsafe wheel"):
                    install.archive(path, install.digest(path.read_bytes()))

    def test_symlink_wheel_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "actual").write_bytes(b"data")
            (root / "link").symlink_to(root / "actual")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                install.archive(root / "link", install.digest(b"data"))

    def test_receipt_cannot_authorize_new_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            environment = Path(tmp)
            (environment / "installation-provenance.json").write_text('{"forged":true}')
            with patch.object(install, "verify", return_value={"approved": True}):
                with self.assertRaisesRegex(ValueError, "receipt differs"):
                    install.checked_tool(environment)

    def test_existing_environment_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "must be new"):
                install.install(Path(tmp))

    def test_exact_release_member_names(self):
        self.assertEqual(len(install.MEMBERS), 41)
        self.assertEqual(len(install.MODULES), 35)
        self.assertIn("ada_gnatdoc_enhancer/adapters/mel.py", install.MEMBERS)


class OperationRegression(unittest.TestCase):
    def test_order_category_label_and_destination_are_not_interchangeable(self):
        text = ('<section class="operation-group" data-category="filtering"><ul>'
                '<li><a href="package.html#first" target=document-content>Blur (1)</a></li>'
                '<li><a href="package.html#second" target=document-content>Blur (2)</a></li>'
                '</ul></section>')
        expected = [{"category": "filtering", "href": "package.html#first", "label": "Blur (1)"},
                    {"category": "filtering", "href": "package.html#second", "label": "Blur (2)"}]
        self.assertEqual(Operations(text).links, expected)
        for mutant in (text.replace("Blur (1)", "Blur (66)"),
                       text.replace("#first", "#second"),
                       text.replace('data-category="filtering"', 'data-category="wrong"')):
            with self.subTest(mutant=mutant):
                self.assertNotEqual(Operations(mutant).links, expected)
        self.assertNotEqual(list(reversed(expected)), expected)


@unittest.skipUnless(os.environ.get("RELEASE_TEST_VENV"), "requires isolated release install")
class InstalledMutations(unittest.TestCase):
    def test_asset_module_metadata_launcher_and_receipt_tampering(self):
        environment = Path(os.environ["RELEASE_TEST_VENV"])
        site = Path(install.run(str(environment / "bin/python"), "-I", "-c",
                    "import sysconfig;print(sysconfig.get_path('purelib'))").decode().strip())
        paths = [site / "ada_gnatdoc_enhancer/assets/gnatdoc-navigation.js",
                 site / "ada_gnatdoc_enhancer/navigation.py",
                 site / install.DIST / "METADATA", environment / "bin/gnatdoc-enhancer",
                 environment / "installation-provenance.json"]
        install.checked_tool(environment)
        for path in paths:
            original = path.read_bytes()
            with self.subTest(path=str(path)):
                try:
                    path.write_bytes(original + b"\nTAMPERED\n")
                    with self.assertRaises((ValueError, __import__("json").JSONDecodeError)):
                        install.checked_tool(environment)
                finally:
                    path.write_bytes(original)
        install.checked_tool(environment)


if __name__ == "__main__":
    unittest.main()