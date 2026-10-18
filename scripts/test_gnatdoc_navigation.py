#!/usr/bin/env python3
"""Mutation tests for the operation-level browser on the generated site."""

import contextlib
import io
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

from enhance_gnatdoc_navigation import (CATEGORIES, check_navigation, enhance,
                                        entries, load_categories)
from link_gnatdoc_types import CrossReferenceError
from validate_docs import DocumentationError, validate

ROOT = Path(__file__).resolve().parent.parent


class CategoryManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "categories.json"
        self.data = json.loads(CATEGORIES.read_text(encoding="utf-8"))

    def tearDown(self):
        self.temporary.cleanup()

    def write(self):
        self.path.write_text(json.dumps(self.data), encoding="utf-8")
        return self.path

    def test_repository_manifest_covers_each_public_name_once(self):
        categories, owner = load_categories()
        self.assertEqual(len(categories), 8)
        self.assertEqual(len(owner), 276)
        self.assertEqual(owner["Box_Filter"], "filtering")
        self.assertEqual(owner["Match_Template"], "matching")
        self.assertEqual(owner["Phase_Correlate"], "registration")
        self.assertEqual(owner["Warp_Affine"], "geometry")
        self.assertEqual(owner["Connected_Components"], "contours")
        self.assertEqual(owner["Connected_Component_Algorithm"], "contours")
        self.assertEqual(owner["Connected_Component_Label_Depth"], "contours")

    def test_duplicate_membership_is_rejected(self):
        self.data["categories"][0]["declarations"].append("Match_Template")
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())

    def test_bad_version_and_empty_category_are_rejected(self):
        self.data["version"] = 2
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())
        self.data["version"] = 1
        self.data["categories"][0]["declarations"] = []
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())


@unittest.skipUnless((ROOT / "_site/api/gnatdoc-navigation.js").is_file(),
                     "generated site not present; run scripts/generate_docs.sh")
class GeneratedNavigationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / "_site"
        shutil.copytree(ROOT / "_site", self.site)
        self.api = self.site / "api"
        self.index = self.api / "index.html"

    def tearDown(self):
        self.temporary.cleanup()

    def edit(self, old, new):
        text = self.index.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        self.index.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertRejected(self, fragment="unapproved navigation"):
        with self.assertRaises(CrossReferenceError) as caught:
            check_navigation(self.api)
        self.assertIn(fragment, str(caught.exception))
        with self.assertRaises(DocumentationError):
            validate(self.site, ROOT)

    def test_every_declaration_has_one_verified_entry(self):
        page, groups = entries(self.api)
        items = [item for _, _, group in groups for item in group]
        self.assertEqual(len(items), 321)
        text = (self.api / page).read_text(encoding="utf-8")
        anchors = set(re.findall(r"<h4 id=([^ >]+)>", text))
        self.assertEqual({item["href"].split("#")[1] for item in items}, anchors)
        index = self.index.read_text(encoding="utf-8")
        self.assertEqual(index.count("<li data-op="), 321)
        match = [i for i in items if i["name"] == "Match_Template"]
        self.assertEqual([(i["overload"], i["overloads"]) for i in match], [(1, 2), (2, 2)])
        for name in ("Box_Filter", "Canny_Edges", "Connected_Components_With_Stats"):
            overloads = [i for i in items if i["name"] == name]
            self.assertEqual([(i["overload"], i["overloads"]) for i in overloads],
                             [(1, 2), (2, 2)])
        self.assertIn("overload 2 of 4", index)

    def test_enhancement_is_idempotent(self):
        before = {p.name: p.read_bytes() for p in self.api.iterdir()}
        with contextlib.redirect_stdout(io.StringIO()):
            enhance(self.api)
        self.assertEqual({p.name: p.read_bytes() for p in self.api.iterdir()}, before)

    def test_wrong_but_existing_destination_is_rejected(self):
        index = self.index.read_text(encoding="utf-8")
        hrefs = re.findall(r'<li data-op="(?:Gaussian_Blur|Resize)"[^>]*><a href=([^ >]+)', index)
        self.assertEqual(len(hrefs), 2)
        self.edit(hrefs[0], hrefs[1])
        self.assertRejected()

    def test_missing_entry_is_rejected(self):
        entry = re.search(r'<li data-op="Warp_Polar".*?</a>', self.index.read_text())[0]
        self.edit(entry, "")
        self.assertRejected()

    def test_inline_handler_and_extra_script_are_rejected(self):
        self.edit("<button id=api-clear type=button>",
                  "<button id=api-clear type=button onclick=alert(1)>")
        self.assertRejected()

    def test_second_script_is_rejected(self):
        self.edit('<body class=main>', '<script src=x.js></script><body class=main>')
        self.assertRejected()

    def test_tampered_script_asset_is_rejected(self):
        asset = self.api / "gnatdoc-navigation.js"
        asset.write_text(asset.read_text(encoding="utf-8") + "\n//x\n", encoding="utf-8")
        self.assertRejected("navigation asset differs")

    def test_changed_frame_target_is_rejected(self):
        self.edit("target=document-content title=", "target=_blank title=")
        self.assertRejected()


if __name__ == "__main__":
    unittest.main()
