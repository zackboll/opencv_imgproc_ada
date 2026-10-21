#!/usr/bin/env python3
"""Negative-first qualification of authoritative guide reconstruction.

Needs the pinned Markdown renderer (docs/requirements.txt) and a generated
`_site`; run with the documentation Python environment.
"""
import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

try:
    import markdown_it  # noqa: F401
    RENDERER = True
except ImportError:
    RENDERER = False


@unittest.skipUnless(RENDERER and (ROOT / "_site/api/gnatdoc-navigation.js").is_file(),
                     "needs the pinned renderer and a generated site")
class Guides(unittest.TestCase):
    def setUp(self):
        import render_gnatdoc_guides as guides
        self.guides = guides
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.site = Path(self.tmp.name) / "site"
        shutil.copytree(ROOT / "_site", self.site)
        shutil.rmtree(self.site / "guides", ignore_errors=True)
        with contextlib.redirect_stdout(io.StringIO()):
            guides.generate(ROOT, self.site)
        self.page = self.site / "guides/template-matching-and-registration.html"
        self.repo = Path(self.tmp.name) / "repo"
        for part in ("src", "docs", "scripts"):
            shutil.copytree(ROOT / part, self.repo / part,
                            ignore=shutil.ignore_patterns("__pycache__"))

    def rejected(self, root=None):
        with self.assertRaises(ValueError):
            self.guides.validate(root or ROOT, self.site)

    def mutation(self, old, new):
        text = self.page.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        self.page.write_text(text.replace(old, new, 1), encoding="utf-8")
        self.rejected()

    def source_mutation(self, name, old, new):
        path = self.repo / "docs/guides" / name
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        with self.assertRaises(ValueError):
            self.guides.expected(self.repo, self.site)

    def test_generated_guides_validate(self):
        self.assertEqual(self.guides.validate(ROOT, self.site), 5)

    def test_missing_and_extra_pages_are_rejected(self):
        shutil.copy(self.page, self.page.with_name("duplicate.html"))
        self.rejected()
        self.page.with_name("duplicate.html").unlink()
        self.page.unlink()
        self.rejected()

    def test_wrong_but_existing_api_anchor_is_rejected(self):
        api = self.guides.api_destinations(self.site, ROOT)
        self.mutation(api[("Match_Template", 2)], api[("Match_Template", 1)])

    def test_wrong_but_existing_guide_link_is_rejected(self):
        self.mutation('href="filtering-and-transforms.html"',
                      'href="color-and-image-representation.html"')

    def test_missing_guide_heading_is_rejected(self):
        self.source_mutation("features-and-structural-analysis.md",
                             "(filtering-and-transforms.md)",
                             "(filtering-and-transforms.md#no-such-heading)")

    def test_code_and_text_mutations_are_rejected(self):
        self.mutation('ada-number">8</span>', 'ada-number">9</span>')

    def test_script_and_handler_are_rejected(self):
        self.mutation("</main>", "<script>alert(1)</script></main>")

    def test_tampered_stylesheet_is_rejected(self):
        css = self.site / "guides/gnatdoc-guides.css"
        css.write_text(css.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        self.rejected()

    def test_unknown_api_declaration_is_rejected(self):
        self.source_mutation("template-matching-and-registration.md",
                             "(api:Phase_Correlate)", "(api:Phase_Correlation)")

    def test_unknown_overload_is_rejected(self):
        self.source_mutation("template-matching-and-registration.md",
                             "(api:Match_Template/2)", "(api:Match_Template/3)")

    def test_ada_code_that_is_not_a_compiled_example_is_rejected(self):
        self.source_mutation("template-matching-and-registration.md",
                             "Radius => 8,\n         Color  => OpenCV.Make_Scalar (1.0));\n"
                             "      Fill_Circle\n        (Second,",
                             "Radius => 7,\n         Color  => OpenCV.Make_Scalar (1.0));\n"
                             "      Fill_Circle\n        (Second,")

    def test_example_missing_from_guides_is_rejected(self):
        (self.repo / "docs/examples/unused.adb").write_text(
            "procedure Unused is\nbegin\n   null;\nend Unused;\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.guides.expected(self.repo, self.site)

    def test_unapproved_link_targets_are_rejected(self):
        for link in ("https://example.com/", "javascript:alert(1)",
                     "../README.md", "missing-guide.md"):
            with self.subTest(link=link):
                self.source_mutation(
                    "filtering-and-transforms.md",
                    "[Gaussian_Blur](api:Gaussian_Blur)", f"[Gaussian_Blur]({link})")
                shutil.copy(ROOT / "docs/guides/filtering-and-transforms.md",
                            self.repo / "docs/guides/filtering-and-transforms.md")

    def test_raw_html_is_rejected(self):
        self.source_mutation("filtering-and-transforms.md", "## Smoothing",
                             "## Smoothing\n\n<div>raw</div>")


if __name__ == "__main__":
    unittest.main()
