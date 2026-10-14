#!/usr/bin/env python3
"""Source-backed type link, theme and highlighting tests on a native fixture."""

import contextlib
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

from highlight_gnatdoc_ada import highlight, strip_highlighting
from install_gnatdoc_theme import NATIVE, check_theme, install
from link_gnatdoc_types import (CORE_DESTINATIONS, LINK, CrossReferenceError,
                                process)

PAGE = "e" * 64 + ".html"
SPEC = textwrap.dedent(
    """\
    package OpenCV.Demo is
       type Mode is (Fast, Exact);
       subtype Count is Natural range 0 .. 9;
       type Pair is record
          Image : OpenCV.Core.Mat;
          Kind  : Mode;
       end record;
       type Pair_Array is array (Positive range <>) of Pair;
       type Colors is (Red, Green, Blue, Cyan, Magenta, Yellow);
       procedure Run
         (Image : OpenCV.Core.Mat; Kind : Mode := Fast; Area : OpenCV.Size);
       function Make (Value : Count) return Pair;
       function Probe (Value : OpenCV.Core.Absent; Unit : OpenCV.Angle_Unit)
          return Boolean;
       procedure Shadow (Count : Natural; Limit : Positive);
    end OpenCV.Demo;
    """
)
CORE_ROOT = ("package OpenCV is\n   type Size is record\n      Width : Integer;\n"
             "   end record;\n   type Angle_Unit is (Radians, Degrees);\nend OpenCV;\n")
CORE = ("package OpenCV.Core is\n   type Mat is tagged private;\nprivate\n"
        "   type Mat is tagged record\n      Handle : Integer;\n   end record;\n"
        "end OpenCV.Core;\n")
SNIPPETS = [
    ("Colors", "type Colors is\n  (Red,\n   Green,\n   …,\n   Yellow);"),
    ("Count", "subtype Count is Natural range 0 .. 9;"),
    ("Make", "function Make (Value : Count) return Pair"),
    ("Mode", "type Mode is (Fast, Exact);"),
    ("Pair", "type Pair is record\n   Image : OpenCV.Core.Mat;\n   Kind  : Mode;\nend record;"),
    ("Pair_Array", "type Pair_Array is array (Positive range &lt;&gt;) of Pair;"),
    ("Probe", "function Probe (Value : OpenCV.Core.Absent; Unit : OpenCV.Angle_Unit)\n"
              "   return Boolean"),
    ("Run", "procedure Run\n  (Image : OpenCV.Core.Mat; Kind : Mode := Fast; "
            "Area : OpenCV.Size)"),
    ("Shadow", "procedure Shadow (Count : Natural; Limit : Positive)"),
]
ANCHORS = {name: hashlib.sha256(name.encode()).hexdigest() for name, _ in SNIPPETS}


def native_page():
    sections = "".join(
        f"<h4 id={ANCHORS[name]}>{name}</h4><pre class=ada-code-snippet><code>"
        f"{code}\n</code></pre><p>About {name}." for name, code in SNIPPETS)
    return ("<!DOCTYPE html>\n<html class=main>\n" + NATIVE +
            "<body class=content><h1>OpenCV.Demo</h1><h2>Description</h2>" + sections)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.src = base / "repo/src"
        self.src.mkdir(parents=True)
        (self.src / "opencv-demo.ads").write_text(SPEC, encoding="utf-8")
        self.core = base / "core"
        (self.core / "src").mkdir(parents=True)
        (self.core / "src/opencv.ads").write_text(CORE_ROOT, encoding="utf-8")
        (self.core / "src/opencv-core.ads").write_text(CORE, encoding="utf-8")
        self.api = base / "_site/api"
        self.api.mkdir(parents=True)
        self.page = self.api / PAGE
        self.page.write_text(native_page(), encoding="utf-8")
        (self.api / "index.html").write_text(
            "<!DOCTYPE html>\n<html class=main>\n" + NATIVE + "<body class=main>"
            f"<a href={PAGE} target=document-content>OpenCV.Demo</a>", encoding="utf-8")
        (self.api / "gnatdoc.css").write_text("/* native */\n", encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def run_step(self, step, *args, **options):
        with contextlib.redirect_stdout(io.StringIO()):
            return step(*args, **options)

    def link(self, **options):
        return self.run_step(process, self.api, self.src, self.core, **options)

    def test_cli_uses_resolved_core_environment(self):
        self.run_step(install, self.api)
        script = Path(__file__).with_name('link_gnatdoc_types.py')
        environment = dict(os.environ, DOC_CORE_SOURCE=str(self.core))
        result = subprocess.run(
            [sys.executable, str(script), str(self.api), '--sources', str(self.src)],
            env=environment, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Core package links', result.stdout)

    def enhance(self):
        self.run_step(install, self.api)
        self.link()
        self.link(highlight=True)

    def section(self, name):
        text = self.page.read_text(encoding="utf-8")
        start = text.index(f">{name}</h4>")
        return text[start:text.index("</code>", start)]

    def edit(self, path, old, new):
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertCheckFails(self, fragment):
        with self.assertRaises(CrossReferenceError) as caught:
            self.link(check=True)
        self.assertIn(fragment, str(caught.exception))


class TypeLinkTest(Fixture):
    def test_links_local_and_core_types_only(self):
        counts, families = self.link()
        self.assertEqual(counts["linked"], 5)
        self.assertEqual(counts["external"], 4)
        run = self.section("Run")
        self.assertIn(f'<a class="type-reference" href="#{ANCHORS["Mode"]}" '
                      'data-type="opencv.demo.mode">Mode</a>', run)
        self.assertIn('<a class="type-reference" href="'
                      + CORE_DESTINATIONS["opencv.core"] +
                      '" data-type="opencv.core.mat" target="_top">OpenCV.Core.Mat</a>', run)
        self.assertIn('href="' + CORE_DESTINATIONS["opencv"] +
                      '" data-type="opencv.size" target="_top">OpenCV.Size</a>', run)
        self.assertIn('data-type="opencv.demo.pair">Pair</a>', self.section("Pair_Array"))
        self.assertIn('data-type="opencv.demo.count">Count</a>', self.section("Make"))
        self.assertIn('data-type="opencv.demo.pair">Pair</a>', self.section("Make"))

    def test_standard_unknown_and_shadowed_names_stay_unlinked(self):
        self.link()
        probe = self.section("Probe")
        self.assertNotIn("opencv.core.absent", probe)
        self.assertIn('data-type="opencv.angle_unit"', probe)
        self.assertNotIn("type-reference", self.section("Shadow"))
        self.assertNotIn(">Natural</a>", self.section("Count"))
        self.assertNotIn(">Boolean</a>", probe)

    def test_text_is_preserved_and_elided_enumeration_matches(self):
        self.link()
        text = self.page.read_text(encoding="utf-8")
        self.assertEqual(LINK.sub(lambda m: m[3], text), native_page())

    def test_check_passes_and_repeated_steps_are_byte_identical(self):
        self.enhance()
        snapshot = {p.name: p.read_bytes() for p in self.api.iterdir()}
        self.link(check=True)
        self.enhance()
        self.assertEqual({p.name: p.read_bytes() for p in self.api.iterdir()}, snapshot)
        self.run_step(check_theme, self.api)

    def test_wrong_but_existing_destination_is_rejected(self):
        self.link()
        self.edit(self.page, f'href="#{ANCHORS["Mode"]}"', f'href="#{ANCHORS["Pair"]}"')
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_fabricated_core_fragment_is_rejected(self):
        self.link()
        self.edit(self.page, CORE_DESTINATIONS["opencv.core"] + '"',
                  CORE_DESTINATIONS["opencv.core"] + '#mat"')
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_removed_core_type_is_rejected(self):
        self.link()
        self.edit(self.core / "src/opencv.ads", "type Angle_Unit", "type Angle_Kind")
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_modified_declaration_text_is_rejected(self):
        self.link()
        self.edit(self.page, "Limit : Positive", "Limit : Natural")
        self.assertCheckFails("source profile not unique")

    def test_modified_html_outside_snippets_is_rejected(self):
        self.link()
        self.edit(self.page, "<p>About Run.", "<p>About Running.")
        self.assertCheckFails("non-snippet HTML changed")

    def test_missing_or_corrupted_manifest_is_rejected(self):
        self.link()
        manifest = self.api / "type-crossrefs.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["snippets"][1] = data["snippets"][1].replace("0 .. 9", "0 .. 8")
        manifest.write_text(json.dumps(data), encoding="utf-8")
        self.assertCheckFails("original Ada declaration text changed")
        manifest.unlink()
        self.assertCheckFails("missing cross-reference integrity manifest")

    def test_unknown_markup_in_snippet_is_rejected(self):
        self.edit(self.page, "function Make", "<b>function</b> Make")
        with self.assertRaises(CrossReferenceError):
            self.link()

    def test_linking_without_manifest_after_linking_is_rejected(self):
        self.link()
        (self.api / "type-crossrefs.json").unlink()
        with self.assertRaises(CrossReferenceError):
            self.link()

    def test_highlight_requires_qualified_links(self):
        with self.assertRaises(CrossReferenceError):
            self.link(highlight=True)


class ThemeTest(Fixture):
    def test_theme_installs_metadata_once_and_verifies(self):
        self.run_step(install, self.api)
        text = self.page.read_text(encoding="utf-8")
        self.assertEqual(text.count('href="gnatdoc-theme.css"'), 1)
        self.assertIn('<meta name="viewport"', text)
        self.run_step(install, self.api)
        self.assertEqual(self.page.read_text(encoding="utf-8"), text)

    def test_theme_rejects_native_and_asset_changes(self):
        self.run_step(install, self.api)
        (self.api / "gnatdoc-theme.css").write_text("body{}", encoding="utf-8")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)

    def test_theme_rejects_changed_native_stylesheet(self):
        self.run_step(install, self.api)
        (self.api / "gnatdoc.css").write_text("/* changed */", encoding="utf-8")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)

    def test_theme_rejects_non_snippet_change(self):
        self.run_step(install, self.api)
        self.edit(self.page, "<p>About Mode.", "<p>About Mode!")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)


class HighlightTest(unittest.TestCase):
    def assert_token(self, text, category, value):
        output = highlight(text)
        self.assertIn(f'<span class="ada-{category}">{value}</span>', output)
        self.assertEqual(strip_highlighting(output), text)

    def test_keywords_respect_identifier_boundaries(self):
        self.assert_token('FuNcTiOn functional return_value RETURN', 'keyword', 'FuNcTiOn')
        self.assertNotIn('>functional</span>', highlight('functional'))

    def test_literals_attributes_and_operators(self):
        self.assert_token('"return ""x"""', 'string', '"return ""x"""')
        self.assert_token("'A'", 'character', "'A'")
        self.assert_token("A'Last", 'attribute', "'Last")
        for number in ('0', '1.0', '16#FF#', '2_147_483_647', '1.0e-5'):
            self.assert_token(number, 'number', number)
        for operator in (':=', '=&gt;', '..', '&lt;&gt;'):
            self.assert_token(operator, 'operator', operator)

    def test_links_with_top_target_stay_atomic(self):
        link = ('<a class="type-reference" href="' + CORE_DESTINATIONS["opencv.core"] +
                '" data-type="opencv.core.mat" target="_top">OpenCV.Core.Mat</a>')
        output = highlight('function F return ' + link)
        self.assertEqual([m[0] for m in LINK.finditer(output)], [link])


if __name__ == "__main__":
    unittest.main()
