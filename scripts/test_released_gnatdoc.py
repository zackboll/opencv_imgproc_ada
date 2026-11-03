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
        install.approved_url(f"https://github.com/a/b/releases/download/v{install.VERSION}/tool.whl")
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
        self.assertEqual(install.VERSION, "0.1.5")
        self.assertEqual(len(install.MEMBERS), 48)
        self.assertEqual(len(install.MODULES), 42)
        self.assertIn("ada_gnatdoc_enhancer/adapters/mel.py", install.MEMBERS)
        # v0.1.5 additions must be explicitly derived, not inherited from v0.1.1.
        for name in ("examples.py", "external_symbols.py", "search.py", "verified_examples.py",
                     "assets/gnatdoc-examples.css", "assets/gnatdoc-search.css",
                     "assets/gnatdoc-search.js"):
            self.assertIn("ada_gnatdoc_enhancer/" + name, install.MEMBERS)
        self.assertTrue(all(m.startswith(("ada_gnatdoc_enhancer/", install.DIST))
                            for m in install.MEMBERS))
        self.assertEqual(set(install.SIZES), {install.WHEEL, install.SDIST,
                                              "release-provenance.json", "SHA256SUMS"})


def synthetic_members(requires=None, extra=("guides",)):
    """A minimal internally consistent wheel; mutations must each be rejected."""
    requires = install.OPTIONAL_DEPENDENCIES if requires is None else requires
    metadata = ("Metadata-Version: 2.4\nName: ada-gnatdoc-enhancer\nVersion: "
                + install.VERSION + "\n" + "".join("Provides-Extra: %s\n" % e for e in extra)
                + "".join("Requires-Dist: %s\n" % r for r in requires) + "\nREADME\n")
    members = {"ada_gnatdoc_enhancer/__init__.py": b'__version__ = "0.1.5"\n',
               install.DIST + "METADATA": metadata.encode(),
               install.DIST + "entry_points.txt":
                   b"[console_scripts]\ngnatdoc-enhancer = ada_gnatdoc_enhancer.cli:main\n",
               install.DIST + "top_level.txt": b"ada_gnatdoc_enhancer\n"}
    rows = [f"{name},{install.record_hash(data)},{len(data)}" for name, data in members.items()]
    members[install.DIST + "RECORD"] = ("\n".join(rows + [install.DIST + "RECORD,,"]) + "\n").encode()
    return members


class ReleaseMetadataControls(unittest.TestCase):
    def test_consistent_record_and_dependencies_accepted(self):
        members = synthetic_members()
        self.assertEqual(install.wheel_record(members), 5)
        self.assertEqual(install.dependencies(members), install.OPTIONAL_DEPENDENCIES)

    def test_record_hash_size_inventory_and_self_entry_mutations(self):
        members = synthetic_members()
        record = members[install.DIST + "RECORD"].decode()
        name = "ada_gnatdoc_enhancer/__init__.py"
        good = install.record_hash(members[name])
        mutations = [
            record.replace(good, install.record_hash(b"other")),
            record.replace(good + ",%d" % len(members[name]), good + ",999"),
            "\n".join(l for l in record.splitlines() if not l.startswith(name)) + "\n",
            record + "ada_gnatdoc_enhancer/extra.py,sha256=AAAA,1\n",
            record.replace(install.DIST + "RECORD,,", install.DIST + "RECORD,sha256=AAAA,1"),
            record + record.splitlines()[0] + "\n",
            record.replace(",", ";", 1)]
        for mutated in mutations:
            with self.subTest(mutated=mutated), self.assertRaises(ValueError):
                install.wheel_record({**members, install.DIST + "RECORD": mutated.encode()})
        with self.assertRaisesRegex(ValueError, "RECORD hash"):
            install.wheel_record({**members, name: b"tampered"})

    def test_mandatory_or_changed_dependencies_rejected(self):
        for requires, extra in (
                (install.OPTIONAL_DEPENDENCIES + ["requests"], ("guides",)),
                (['markdown-it-py==3.0.0', 'mdurl==0.1.2; extra == "guides"'], ("guides",)),
                (['markdown-it-py==3.0.1; extra == "guides"', 'mdurl==0.1.2; extra == "guides"'],
                 ("guides",)),
                (install.OPTIONAL_DEPENDENCIES, ("guides", "search"))):
            with self.subTest(requires=requires), self.assertRaises(ValueError):
                install.dependencies(synthetic_members(requires, extra))
        members = synthetic_members()
        for name, data in ((install.DIST + "METADATA",
                            members[install.DIST + "METADATA"].replace(b"0.1.5", b"0.1.1")),
                           (install.DIST + "entry_points.txt",
                            b"[console_scripts]\ngnatdoc-enhancer = os:system\n"),
                           (install.DIST + "top_level.txt", b"ada_gnatdoc_enhancer\nevil\n")):
            with self.subTest(name=name), self.assertRaises(ValueError):
                install.dependencies({**members, name: data})

    def test_checksum_inventory_mutations(self):
        good = "".join(f"{sha}  {name}\n" for name, sha in (
            (install.WHEEL, install.WHEEL_HASH), (install.SDIST, install.SDIST_HASH),
            ("release-provenance.json", install.PROVENANCE_HASH)))
        install.checksums(good.encode())
        for mutated in (good.replace(install.SDIST_HASH, "0" * 64),
                        good + f"{'1' * 64}  extra.whl\n",
                        "\n".join(good.splitlines()[:2]) + "\n",
                        good + good.splitlines()[0] + "\n",
                        good.replace(install.WHEEL, "ada_gnatdoc_enhancer-0.1.1-py3-none-any.whl")):
            with self.subTest(mutated=mutated), self.assertRaises(ValueError):
                install.checksums(mutated.encode())

    def test_provenance_cross_binding_mutations(self):
        members = synthetic_members()
        wheel = {"name": install.WHEEL, "sha256": install.WHEEL_HASH,
                 "bytes": install.SIZES[install.WHEEL],
                 "members": {k: {"bytes": len(v), "sha256": install.digest(v)}
                             for k, v in members.items()}}
        good = {"release_version": install.VERSION, "expected_source_commit": install.COMMIT,
                "expected_source_tree": install.TREE,
                "archives": {"wheel": wheel, "sdist": {
                    "name": install.SDIST, "sha256": install.SDIST_HASH,
                    "bytes": install.SIZES[install.SDIST]}},
                "distribution_content_audit": {
                    "version": install.VERSION, "runtime_dependencies": [],
                    "optional_guides_dependencies": install.OPTIONAL_DEPENDENCIES,
                    "wheel_record_hashes_and_sizes_verified": True,
                    "module_asset_sha256": {k: install.digest(v) for k, v in members.items()
                                            if k.startswith("ada_gnatdoc_enhancer/")}}}
        encode = lambda value: __import__("json").dumps(value).encode()
        install.release_provenance(encode(good), members)
        import copy
        def mutate(path, value):
            record = copy.deepcopy(good)
            target = record
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            return record
        for path, value in ((("expected_source_commit",), install.TAG),
                            (("expected_source_tree",), "0" * 40),
                            (("release_version",), "0.1.1"),
                            (("archives", "wheel", "sha256"), "0" * 64),
                            (("archives", "sdist", "bytes"), 1),
                            (("archives", "wheel", "members"), {}),
                            (("distribution_content_audit", "runtime_dependencies"), ["requests"]),
                            (("distribution_content_audit", "module_asset_sha256"), {}),
                            (("distribution_content_audit",
                              "wheel_record_hashes_and_sizes_verified"), False)):
            with self.subTest(path=path), self.assertRaises(ValueError):
                install.release_provenance(encode(mutate(path, value)), members)


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
                 environment / "installation-provenance.json",
                 environment / "release-provenance.json", environment / "SHA256SUMS",
                 environment / "approved-archives" / install.WHEEL,
                 site / install.DIST / "direct_url.json",
                 site / install.DIST / "RECORD",
                 site / "ada_gnatdoc_enhancer/assets/gnatdoc-search.js",
                 site / "ada_gnatdoc_enhancer/verified_examples.py"]
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
        record = site / install.DIST / "RECORD"
        original = record.read_bytes()
        for row in (b"ada_gnatdoc_enhancer/evil.py,sha256=AAAA,1\n",
                    b"../../../bin/other-tool,sha256=AAAA,1\n",
                    b"ada_gnatdoc_enhancer/__pycache__/evil.cpython-313.pyc,,\n"):
            with self.subTest(row=row):
                try:
                    record.write_bytes(original + row)
                    with self.assertRaisesRegex(ValueError, "unapproved installed"):
                        install.checked_tool(environment)
                finally:
                    record.write_bytes(original)
        install.checked_tool(environment)


if __name__ == "__main__":
    unittest.main()