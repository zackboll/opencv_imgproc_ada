#!/usr/bin/env python3
"""Mutation tests for the generated-site validator.

The synthetic fixture reproduces the pinned GNATdoc 26.0.0 serialization of a
small specification, so every rule runs without GNATdoc. When a generated
`_site` exists, the same rejections are also exercised on a copy of it.
"""

import shutil
import tempfile
import textwrap
import unittest
from pathlib import Path

from validate_docs import DocumentationError, validate

ROOT = Path(__file__).resolve().parent.parent
PAGE = "a" * 64 + ".html"

SPEC = textwrap.dedent(
    """\
    package OpenCV.Demo is

       type Mode is (Fast, Exact);

       --  Runs the demonstration.
       procedure Run (Value : Integer);
       procedure Run (Value : Integer; Selected : Mode);

       function Count return Natural;

       Limit : constant := 3;

    private

       function Hidden return Boolean;

    end OpenCV.Demo;
    """
)

INTERNAL = "package OpenCV.Demo.Internal is\nend OpenCV.Demo.Internal;\n"

INDEX = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=main><div class=side-navigation><ul class=tab-bar>"
    "<li class=tab><a href=#compilation-units>Compilation Units</a>"
    "<li class=tab><a href=#tagged-types>Tagged Types</a></ul>"
    "<div class=content-column><h2 id=compilation-units>Compilation Units</h2>"
    f"<ul><li><a href={PAGE} target=document-content>OpenCV.Demo</a></ul>"
    "<h2 id=tagged-types>Tagged types</h2><ul></ul></div></div>"
    "<div class=document-content><iframe name=document-content></iframe></div>"
)


def section(anchor, name, code, text=""):
    return (
        f"<h4 id={anchor}>{name}</h4><pre class=ada-code-snippet><code>"
        f"{code}\n</code></pre>{text}"
    )


PACKAGE = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=content><h1>OpenCV.Demo</h1><h2>Entities</h2>"
    "<h3>Simple Types</h3><ul><li><a href=#t1>Mode</a></ul>"
    "<h3>Constants</h3><ul><li><a href=#c1>Limit</a></ul>"
    "<h3>Subprograms</h3><ul><li><a href=#s1>Count</a><li><a href=#s2>Run</a>"
    "<li><a href=#s3>Run</a></ul><h2>Description</h2>"
    + section("t1", "Mode", "type Mode is (Fast, Exact)")
    + section("c1", "Limit", "Limit : constant := 3;")
    + section("s1", "Count", "function Count return Natural")
    + section("s2", "Run", "procedure Run (Value : Integer)",
              "<p>Runs the demonstration.")
    + section("s3", "Run", "procedure Run\n  (Value : Integer; Selected : Mode)")
)

LANDING = (
    '<!doctype html>\n<html lang="en">\n<title>Demo</title>\n<body>\n'
    '<p><a href="api/index.html">API</a>\n'
    '<p><a href="https://github.com/zackboll/opencv_imgproc_ada">Source</a>\n'
)

FIXTURE_OPTIONS = {
    "declarations": ("Mode", "Run", "Count", "Limit"),
    "rendered": {"procedure Run (Value : Integer)": ("Runs the demonstration.",)},
}


class SyntheticSiteTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.root = base / "repo"
        (self.root / "src/internal").mkdir(parents=True)
        (self.root / "src/opencv-demo.ads").write_text(SPEC, encoding="utf-8")
        (self.root / "src/internal/opencv-demo-internal.ads").write_text(
            INTERNAL, encoding="utf-8"
        )
        self.site = base / "_site"
        (self.site / "api").mkdir(parents=True)
        (self.site / "index.html").write_text(LANDING, encoding="utf-8")
        (self.site / "api/index.html").write_text(INDEX, encoding="utf-8")
        (self.site / "api/gnatdoc.css").write_text("body{}\n", encoding="utf-8")
        (self.site / "api" / PAGE).write_text(PACKAGE, encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def validate(self):
        return validate(self.site, self.root, **FIXTURE_OPTIONS)

    def rewrite(self, relative, old, new):
        path = self.site / relative
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertRejected(self, fragment):
        with self.assertRaises(DocumentationError) as caught:
            self.validate()
        self.assertIn(fragment, str(caught.exception))

    def test_native_fixture_is_accepted(self):
        summary = self.validate()
        self.assertEqual(summary["packages"], 1)
        self.assertEqual(summary["pages"], 3)
        self.assertEqual(summary["sections"], 5)
        self.assertEqual(summary["subprograms"], 3)

    def test_missing_stylesheet_is_rejected(self):
        (self.site / "api/gnatdoc.css").unlink()
        self.assertRejected("missing/empty: api/gnatdoc.css")

    def test_broken_fragment_is_rejected(self):
        self.rewrite("api/" + PAGE, "<a href=#s1>", "<a href=#missing>")
        self.assertRejected("missing anchor")

    def test_duplicate_id_is_rejected(self):
        self.rewrite("api/" + PAGE, "<h4 id=s3>", "<h4 id=s2>")
        self.assertRejected("duplicate id")

    def test_script_is_rejected(self):
        self.rewrite("api/" + PAGE, "<h2>Entities</h2>",
                     "<script>alert(1)</script><h2>Entities</h2>")
        self.assertRejected("unapproved active content")

    def test_event_handler_is_rejected(self):
        self.rewrite("api/" + PAGE, "<h1>", "<h1 onclick=go()>")
        self.assertRejected("unapproved active content")

    def test_javascript_url_is_rejected(self):
        self.rewrite("index.html", 'href="api/index.html"',
                     'href="javascript:alert(1)"')
        self.assertRejected("unapproved link")

    def test_root_absolute_link_is_rejected(self):
        self.rewrite("api/" + PAGE, "href=gnatdoc.css", "href=/api/gnatdoc.css")
        self.assertRejected("non-relative local link")

    def test_path_traversal_is_rejected(self):
        self.rewrite("api/" + PAGE, "href=gnatdoc.css",
                     "href=../../repo/src/opencv-demo.ads")
        self.assertRejected("broken link")

    def test_external_link_in_api_page_is_rejected(self):
        self.rewrite("api/" + PAGE, "<a href=#s1>",
                     "<a href=https://example.com/>")
        self.assertRejected("unapproved link")

    def test_unapproved_landing_destination_is_rejected(self):
        self.rewrite("index.html", "https://github.com/zackboll/opencv_imgproc_ada",
                     "https://github.com/zackboll/opencv_imgproc_ada.evil.example")
        self.assertRejected("unapproved link")

    def test_landing_must_link_to_api_reference(self):
        self.rewrite("index.html", 'href="api/index.html"', 'href="#top"')
        self.assertRejected("landing page does not link to api/index.html")

    def test_internal_package_page_is_rejected(self):
        internal = "b" * 64 + ".html"
        (self.site / "api" / internal).write_text(
            PACKAGE.replace("<h1>OpenCV.Demo</h1>", "<h1>OpenCV.Demo.Internal</h1>"),
            encoding="utf-8",
        )
        self.assertRejected("unexpected package page: OpenCV.Demo.Internal")

    def test_stray_file_is_rejected(self):
        (self.site / "api/notes.txt").write_text("x", encoding="utf-8")
        self.assertRejected("unexpected file: api/notes.txt")

    def test_missing_package_page_is_rejected(self):
        (self.site / "api" / PAGE).unlink()
        self.assertRejected("public package missing: OpenCV.Demo")

    def test_index_redirected_to_existing_file_is_rejected(self):
        self.rewrite("api/index.html", f"href={PAGE}", "href=gnatdoc.css")
        self.assertRejected("native API index does not match")

    def test_index_target_change_is_rejected(self):
        self.rewrite("api/index.html", "target=document-content>OpenCV",
                     "target=_blank>OpenCV")
        self.assertRejected("native API index does not match")

    def test_removed_overload_section_is_rejected(self):
        self.rewrite(
            "api/" + PAGE,
            section("s3", "Run", "procedure Run\n  (Value : Integer; Selected : Mode)"),
            "",
        )
        self.rewrite("api/" + PAGE, "<li><a href=#s3>Run</a>", "")
        self.assertRejected("declaration sections differ from the public source")

    def test_changed_overload_profile_is_rejected(self):
        self.rewrite("api/" + PAGE, "procedure Run (Value : Integer)",
                     "procedure Run (Value : Long_Integer)")
        self.assertRejected("declaration sections differ from the public source")

    def test_published_private_declaration_is_rejected(self):
        self.rewrite(
            "api/" + PAGE, "<h2>Description</h2>",
            "<h2>Description</h2>"
            + section("p1", "Hidden", "function Hidden return Boolean"),
        )
        self.assertRejected("declaration sections differ from the public source")

    def test_comment_rendered_in_another_overload_is_rejected(self):
        self.rewrite("api/" + PAGE, "<p>Runs the demonstration.", "")
        self.rewrite(
            "api/" + PAGE,
            "procedure Run\n  (Value : Integer; Selected : Mode)\n</code></pre>",
            "procedure Run\n  (Value : Integer; Selected : Mode)\n</code></pre>"
            "<p>Runs the demonstration.",
        )
        self.assertRejected("lacks rendered text: Runs the demonstration.")

    def test_unmatched_heading_is_rejected(self):
        self.rewrite("api/" + PAGE, "<h2>Description</h2>",
                     "<h2>Description</h2><h4 id=x1>Loose</h4>")
        self.assertRejected("unrecognized declaration heading")

    def test_machine_local_path_is_rejected(self):
        self.rewrite("api/" + PAGE, "<p>Runs the demonstration.",
                     "<p>Runs the demonstration. /home/builder/src")
        self.assertRejected("internal unit or machine-local path")

    def test_internal_unit_name_is_rejected(self):
        self.rewrite("api/" + PAGE, "<p>Runs the demonstration.",
                     "<p>Runs the demonstration. OpenCV.Image_Processing.Internal")
        self.assertRejected("internal unit or machine-local path")

    def test_missing_representative_declaration_is_rejected(self):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, self.root, declarations=("Mode", "Absent"),
                     rendered={})
        self.assertIn("missing representative declaration: Absent", str(caught.exception))

    def test_landing_example_must_match_compiled_example(self):
        (self.root / "docs").mkdir()
        (self.root / "docs/example.adb").write_text(
            "procedure Example is\nbegin\n   null;\nend Example;\n", encoding="utf-8"
        )
        self.assertRejected("landing page example differs from docs/example.adb")
        self.rewrite(
            "index.html", "<body>\n",
            "<body>\n<pre>procedure Example is\nbegin\n   null;\nend Example;</pre>\n",
        )
        self.validate()

    def test_validation_does_not_modify_the_site(self):
        before = {p: p.read_bytes() for p in self.site.rglob("*") if p.is_file()}
        self.validate()
        after = {p: p.read_bytes() for p in self.site.rglob("*") if p.is_file()}
        self.assertEqual(before, after)


@unittest.skipUnless((ROOT / "_site/api/index.html").is_file(),
                     "generated site not present; run scripts/generate_docs.sh")
class GeneratedSiteTest(unittest.TestCase):
    """Mutations of a copy of the real generated site must be rejected."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / "_site"
        shutil.copytree(ROOT / "_site", self.site)
        pages = [p for p in (self.site / "api").glob("*.html") if p.name != "index.html"]
        self.assertEqual(len(pages), 1)
        self.page = pages[0]

    def tearDown(self):
        self.temporary.cleanup()

    def assertRejected(self, fragment):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, ROOT)
        self.assertIn(fragment, str(caught.exception))

    def mutate(self, old, new, count=1):
        text = self.page.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        self.page.write_text(text.replace(old, new, count), encoding="utf-8")

    def test_generated_site_is_accepted(self):
        summary = validate(self.site, ROOT)
        self.assertEqual(summary["packages"], 1)
        self.assertEqual(summary["pages"], 3)

    def test_missing_stylesheet_is_rejected(self):
        (self.site / "api/gnatdoc.css").unlink()
        self.assertRejected("missing/empty: api/gnatdoc.css")

    def test_internal_package_publication_is_rejected(self):
        leak = self.site / "api" / ("c" * 64 + ".html")
        leak.write_text(
            self.page.read_text(encoding="utf-8").replace(
                "<h1>OpenCV.Image_Processing</h1>",
                "<h1>OpenCV.Image_Processing.Internal.C_API</h1>",
            ),
            encoding="utf-8",
        )
        self.assertRejected("unexpected package page")

    def test_broken_declaration_anchor_is_rejected(self):
        self.mutate(">Match_Template</a>", ">Match_Template</a><a href=#0>x</a>")
        self.assertRejected("missing anchor")

    def test_removed_match_template_overload_is_rejected(self):
        text = self.page.read_text(encoding="utf-8")
        start = text.index(">Match_Template</h4>")
        start = text.rindex("<h4 ", 0, start)
        end = text.index("<h4 ", start + 1)
        self.page.write_text(text[:start] + text[end:], encoding="utf-8")
        self.assertRejected("declaration sections differ from the public source")

    def test_modified_native_declaration_text_is_rejected(self):
        self.mutate("function Phase_Correlate\n  (Source_1, Source_2 : OpenCV.Core.Mat)",
                    "function Phase_Correlate\n  (Source_1 : OpenCV.Core.Mat)")
        self.assertRejected("declaration sections differ from the public source")

    def test_injected_script_is_rejected(self):
        self.mutate("<h1>", "<script src=x.js></script><h1>")
        self.assertRejected("unapproved active content")

    def test_changed_landing_example_is_rejected(self):
        landing = self.site / "index.html"
        text = landing.read_text(encoding="utf-8")
        self.assertIn("Sigma       =&gt; 1.0);", text)
        landing.write_text(text.replace("Sigma       =&gt; 1.0);",
                                        "Sigma       =&gt; 2.0);"), encoding="utf-8")
        self.assertRejected("landing page example differs from docs/example.adb")


if __name__ == "__main__":
    unittest.main()
