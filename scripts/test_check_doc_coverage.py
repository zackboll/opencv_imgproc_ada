#!/usr/bin/env python3
"""Mutation tests for the declaration-identity documentation coverage check."""

import contextlib
import io
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

from check_doc_coverage import (check_site, main, parameter_names,
                              rendered_sections, specification)

ROOT = Path(__file__).resolve().parent.parent
PAGE = "d" * 64 + ".html"

SPEC = textwrap.dedent(
    """\
    --  Demonstration package for coverage checks.
    package OpenCV.Demo is

       --  Processing modes for Run.
       --  @enum Fast Favor speed over accuracy.
       --  @enum Exact Favor accuracy over speed.
       type Mode is (Fast, Exact);

       --  Optional value with a presence flag.
       --  @field Present True when Value exists.
       --  @field Value The stored value when present.
       type Optional (Present : Boolean := False) is record
          case Present is
             when False =>
                null;
             when True =>
                Value : Integer;
          end case;
       end record;

       --  Runs the demonstration once.
       --  @param Value Input value to process.
       procedure Run (Value : Integer);

       --  Runs the demonstration in a selected mode.
       --  @param Value Input value to process.
       --  @param Selected Mode used for processing.
       procedure Run (Value : Integer; Selected : Mode);

       --  Counts completed runs so far.
       --  @return Number of completed runs.
       function Count return Natural;

    private

       function Hidden return Boolean;

    end OpenCV.Demo;
    """
)


def section(anchor, name, code, body):
    return (f"<h4 id={anchor}>{name}</h4><pre class=ada-code-snippet><code>"
            f"{code}\n</code></pre>{body}")


PACKAGE = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=content><h1>OpenCV.Demo</h1><h2>Entities</h2><ul></ul>"
    "<h2>Description</h2><p>Demonstration package for coverage checks."
    + section("c1", "Count", "function Count return Natural",
              "<p>Counts completed runs so far.<h5>Return Value</h5><dl><dd>"
              "<p>Number of completed runs.</dl>")
    + section("t1", "Mode", "type Mode is (Fast, Exact);",
              "<p>Processing modes for Run.<h5>Enumeration Literal</h5><dl>"
              "<dt>Fast<dd><p>Favor speed over accuracy.<dt>Exact<dd>"
              "<p>Favor accuracy over speed.</dl>")
    + section("t2", "Optional",
              "type Optional (Present : Boolean := False) is record\n"
              "   case Present is\n      when False =>\n         null;\n"
              "      when True =>\n         Value : Integer;\n   end case;\n"
              "end record;",
              "<p>Optional value with a presence flag.<h5>Record fields</h5><dl>"
              "<dt>Present<dd><p>True when Value exists.<dt>Value<dd>"
              "<p>The stored value when present.</dl>")
    + section("r1", "Run", "procedure Run (Value : Integer)",
              "<p>Runs the demonstration once.<h5>Parameters</h5><dl>"
              "<dt>Value<dd><p>Input value to process.</dl>")
    + section("r2", "Run", "procedure Run (Value : Integer; Selected : Mode)",
              "<p>Runs the demonstration in a selected mode.<h5>Parameters</h5>"
              "<dl><dt>Value<dd><p>Input value to process.<dt>Selected<dd>"
              "<p>Mode used for processing.</dl>")
)


class SyntheticCoverageTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.root = base / "repo"
        (self.root / "src").mkdir(parents=True)
        self.spec = self.root / "src/opencv-demo.ads"
        self.spec.write_text(SPEC, encoding="utf-8")
        self.site = base / "_site"
        (self.site / "api").mkdir(parents=True)
        self.page = self.site / "api" / PAGE
        self.page.write_text(PACKAGE, encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def edit(self, path, old, new):
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def check(self):
        return check_site(self.site, self.root)

    def test_complete_fixture_is_fully_documented(self):
        items, missing, errors = self.check()
        self.assertEqual(errors, [])
        self.assertEqual(missing, [])
        kinds = sorted(items.values())
        self.assertEqual(kinds.count("parameter"), 3)
        self.assertEqual(kinds.count("literal"), 2)
        self.assertEqual(kinds.count("component"), 2)
        self.assertEqual(kinds.count("return"), 1)
        self.assertEqual(kinds.count("procedure"), 2)
        self.assertEqual(len(items), 14)

    def test_empty_parameter_is_undocumented_on_its_own_overload(self):
        self.edit(self.spec, "   --  @param Selected Mode used for processing.\n", "")
        self.edit(self.page, "<dt>Selected<dd><p>Mode used for processing.",
                  "<dt>Selected<dd>")
        _, missing, errors = self.check()
        self.assertEqual(errors, [])
        self.assertEqual(missing, [
            "OpenCV.Demo: procedure Run (Value : Integer; Selected : Mode):"
            " parameter Selected"])

    def test_one_word_and_name_only_text_do_not_count(self):
        self.edit(self.spec, "@enum Fast Favor speed over accuracy.", "@enum Fast Fast.")
        self.edit(self.page, "<p>Favor speed over accuracy.", "<p>Fast.")
        self.edit(self.spec, "@return Number of completed runs.", "@return Count.")
        self.edit(self.page, "<p>Number of completed runs.", "<p>Count.")
        _, missing, errors = self.check()
        self.assertEqual(errors, [])
        self.assertEqual(len(missing), 2)
        self.assertTrue(any(m.endswith("literal Fast") for m in missing))
        self.assertTrue(any(m.endswith(": return") for m in missing))

    def test_missing_overload_description_is_undocumented(self):
        self.edit(self.page, "<p>Runs the demonstration once.", "")
        self.edit(self.spec, "   --  Runs the demonstration once.\n", "")
        _, missing, errors = self.check()
        self.assertEqual(errors, [])
        self.assertEqual(missing, [
            "OpenCV.Demo: procedure Run (Value : Integer): description"])

    def test_missing_package_description_is_undocumented(self):
        self.edit(self.page, "<p>Demonstration package for coverage checks.", "")
        self.edit(self.spec, "--  Demonstration package for coverage checks.\n", "")
        _, missing, _ = self.check()
        self.assertEqual(missing, ["OpenCV.Demo: package: description"])

    def test_package_description_inside_package_is_accepted(self):
        self.edit(self.spec, "--  Demonstration package for coverage checks.\n"
                  "package OpenCV.Demo is\n",
                  "package OpenCV.Demo is\n\n"
                  "   --  Demonstration package for coverage checks.\n")
        self.assertEqual(self.check()[1:], ([], []))

    def test_second_block_inside_package_is_detached(self):
        self.edit(self.spec, "--  Demonstration package for coverage checks.\n"
                  "package OpenCV.Demo is\n",
                  "package OpenCV.Demo is\n\n"
                  "   --  Demonstration package for coverage checks.\n\n"
                  "   --  Stray note.\n")
        _, _, errors = self.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("detached comment", errors[0])

    def test_rendered_member_list_must_match_source(self):
        self.edit(self.page, "<dt>Exact<dd><p>Favor accuracy over speed.", "")
        _, _, errors = self.check()
        self.assertTrue(any("Enumeration Literal differ from source" in e for e in errors))

    def test_missing_discriminant_entry_is_rejected(self):
        self.edit(self.page, "<dt>Present<dd><p>True when Value exists.", "")
        _, _, errors = self.check()
        self.assertTrue(any("Record fields differ from source" in e for e in errors))

    def test_missing_section_is_rejected(self):
        self.edit(self.page, "<h4 id=c1>Count</h4>", "<h4 id=c1>Total</h4>")
        _, _, errors = self.check()
        self.assertTrue(any("function Count return Natural: expected one native"
                            in e for e in errors))

    def test_detached_comment_is_rejected(self):
        self.edit(self.spec, "   --  Counts completed runs so far.\n",
                  "   --  Counts completed runs so far.\n\n")
        _, _, errors = self.check()
        self.assertTrue(any("detached comment" in e for e in errors))

    def test_trailing_comment_is_rejected(self):
        self.edit(self.spec, "   type Mode is (Fast, Exact);\n",
                  "   type Mode is (Fast, Exact);\n   --  Trailing note.\n\n")
        _, _, errors = self.check()
        self.assertTrue(any("detached comment" in e for e in errors))

    def test_comment_rendered_in_another_section_is_rejected(self):
        self.edit(self.page, "<p>Runs the demonstration in a selected mode.",
                  "<p>Runs the demonstration once.")
        _, _, errors = self.check()
        self.assertTrue(any("does not render in the declaration it precedes" in e
                            for e in errors))

    def test_emphasis_mangled_formula_is_rejected(self):
        self.edit(self.spec, "   --  Runs the demonstration once.\n",
                  "   --  Runs the demonstration once as A*B + C*D.\n")
        self.edit(self.page, "<p>Runs the demonstration once.",
                  "<p>Runs the demonstration once as A<em>B + C</em>D.")
        _, _, errors = self.check()
        self.assertTrue(any("does not render" in e for e in errors))

    def test_code_span_formula_is_accepted(self):
        self.edit(self.spec, "   --  Runs the demonstration once.\n",
                  "   --  Runs the demonstration once as `A*B + C*D`.\n")
        self.edit(self.page, "<p>Runs the demonstration once.",
                  "<p>Runs the demonstration once as <code>A*B + C*D</code>.")
        _, missing, errors = self.check()
        self.assertEqual((missing, errors), ([], []))

    def test_code_block_line_starting_with_operator_is_verbatim(self):
        self.edit(self.spec, "   --  Runs the demonstration once.\n",
                  "   --  Runs the demonstration once:\n   --\n"
                  "   --       A\n   --       * B\n   --\n")
        self.edit(self.page, "<p>Runs the demonstration once.",
                  "<p>Runs the demonstration once:<pre><code>A\n* B\n</code></pre>")
        self.assertEqual(self.check()[1:], ([], []))
        self.edit(self.page, "* B\n", "B\n")
        self.assertTrue(any("does not render" in e for e in self.check()[2]))

    def test_private_part_comments_are_not_required_to_render(self):
        self.edit(self.spec, "   function Hidden return Boolean;\n",
                  "   --  Private helper.\n   function Hidden return Boolean;\n")
        self.assertEqual(self.check()[2], [])

    def _main(self, *options):
        baseline = self.root / "baseline.txt"
        with contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            return main([*options, str(baseline), str(self.site), "--root", str(self.root)])

    def test_ratchet_rejects_new_and_stale_gaps(self):
        self.edit(self.spec, "   --  @param Value Input value to process.\n", "")
        self.edit(self.page, "<dt>Value<dd><p>Input value to process.</dl>",
                  "<dt>Value<dd></dl>")
        self.assertEqual(self._main("--write-baseline"), 0)
        self.assertEqual(self._main("--fail-on-removed"), 0)
        self.edit(self.spec, "   --  @param Selected Mode used for processing.\n", "")
        self.edit(self.page, "<dt>Selected<dd><p>Mode used for processing.",
                  "<dt>Selected<dd>")
        self.assertEqual(self._main(), 1)
        self.edit(self.spec, "   procedure Run (Value : Integer; Selected",
                  "   --  @param Selected Mode used here.\n"
                  "   procedure Run (Value : Integer; Selected")
        self.edit(self.page, "<dt>Selected<dd>", "<dt>Selected<dd><p>Mode used here.")
        self.edit(self.spec, "   procedure Run (Value : Integer);",
                  "   --  @param Value Input value.\n   procedure Run (Value : Integer);")
        self.edit(self.page, "<dt>Value<dd></dl>", "<dt>Value<dd><p>Input value.</dl>")
        self.assertEqual(self._main(), 0)
        self.assertEqual(self._main("--fail-on-removed"), 1)

    def test_attachment_errors_cannot_be_baselined(self):
        self.edit(self.spec, "   --  Counts completed runs so far.\n",
                  "   --  Counts completed runs so far.\n\n")
        self.assertEqual(self._main("--write-baseline"), 1)

    def test_parameter_names_follow_profile_order(self):
        self.assertEqual(
            parameter_names("function F (A, B : T; C : in out U : = (X => 1, Y => 2);"
                            " D : V) return W"),
            ["A", "B", "C", "D"])
        self.assertEqual(parameter_names("function Count return Natural"), [])


@unittest.skipUnless((ROOT / "_site/api/index.html").is_file(),
                     "generated site not present; run scripts/generate_docs.sh")
class GeneratedCoverageTest(unittest.TestCase):
    """The checker must see mutations of a copy of the real generated site."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / "_site"
        shutil.copytree(ROOT / "_site", self.site)
        self.page = next(p for p in (self.site / "api").glob("*.html")
                         if p.name != "index.html")
        self.items, self.missing, self.errors = check_site(self.site, ROOT)

    def tearDown(self):
        self.temporary.cleanup()

    def test_generated_site_inventory_matches_source(self):
        self.assertEqual(self.errors, [])
        kinds = list(self.items.values())
        self.assertEqual(self.missing, [])
        self.assertEqual(kinds.count("function") + kinds.count("procedure"), 193)
        self.assertEqual(len(kinds) - kinds.count("parameter") - kinds.count("return")
                         - kinds.count("literal") - kinds.count("component")
                         - kinds.count("package"), 329)
        self.assertEqual(len(kinds), 1596)

    def test_new_overloads_have_their_own_documented_parameters(self):
        sections = rendered_sections(self.page.read_text(encoding="utf-8"))
        expected = {
            "Box_Filter": [
                ["Source", "Destination", "Kernel_Size", "Destination_Depth",
                 "Normalize", "Border"],
                ["Source", "Destination", "Kernel_Size", "Anchor",
                 "Destination_Depth", "Normalize", "Border"]],
            "Canny_Edges": [
                ["Source", "Destination", "Lower_Threshold", "Upper_Threshold",
                 "Aperture", "Gradient_Norm"],
                ["Derivative_X", "Derivative_Y", "Destination",
                 "Lower_Threshold", "Upper_Threshold", "Gradient_Norm"]],
            "Connected_Components_With_Stats": [
                ["Source", "Labels", "Components", "Connectivity"],
                ["Source", "Labels", "Components", "Label_Depth",
                 "Connectivity", "Algorithm"]],
        }
        for name, profiles in expected.items():
            found = [value[0] for (n, kind, _), value in sections.items()
                     if n == name and kind == "procedure"]
            self.assertEqual(len(found), 2, name)
            for names in profiles:
                section = next(s for s in found if
                               [n for n, _ in s["groups"]["Parameters"]] == names)
                self.assertTrue(section["description"])
                self.assertTrue(all(len(text.split()) >= 2
                                    for _, text in section["groups"]["Parameters"]))
        self.assertEqual(self.errors, [])  # includes exact source-text attachment
        self.assertEqual(self.missing, [])

    def test_all_previous_declaration_identities_are_retained(self):
        # Immutable pre-feature public source: compare full profiles, not just
        # names or counts (which could hide replacing an earlier overload).
        baseline = subprocess.run(
            ["git", "show", "0fe5162ba47f91c8b54e66356e9ec9d037ce29dd:"
             "src/opencv-image_processing.ads"], cwd=ROOT, check=True,
            capture_output=True, text=True).stdout
        spec = Path(self.temporary.name) / "previous.ads"
        spec.write_text(baseline, encoding="utf-8")
        _, _, _, _, declarations, _ = specification(spec)
        from validate_docs import _kind, _profile
        identities = {
            "OpenCV.Image_Processing: " +
            (_profile(d["signature"]) if _kind(d["signature"]) in
             ("procedure", "function") else _kind(d["signature"]) + " " + d["name"])
            + ": description" for d in declarations}
        self.assertEqual(len(identities), 317)
        self.assertEqual(identities - self.items.keys(), set())

    def test_swapped_box_overload_parameter_text_is_rejected(self):
        text = self.page.read_text(encoding="utf-8")
        # These descriptions are unique to the two Box_Filter profiles.
        centered = "Positive rectangle; even sizes allowed."
        explicit = "Positive rectangular neighborhood."
        self.assertIn(centered, text)
        self.assertIn(explicit, text)
        text = text.replace(centered, "SWAP_SENTINEL", 1)
        # Locate the explicit Box_Filter section rather than another filter.
        start = text.index(">Box_Filter</h4>", text.index(">Box_Filter</h4>") + 1)
        prefix, tail = text[:start], text[start:]
        self.assertIn(explicit, tail)
        tail = tail.replace(explicit, centered, 1)
        self.page.write_text((prefix + tail).replace("SWAP_SENTINEL", explicit, 1),
                             encoding="utf-8")
        _, _, errors = check_site(self.site, ROOT)
        self.assertTrue(any("does not render" in error for error in errors))

    def test_derivative_parameter_documentation_cannot_attach_to_image_canny(self):
        text = self.page.read_text(encoding="utf-8")
        description = "Signed horizontal derivatives."
        self.assertIn(description, text)
        # Even text still present on the page must fail if it is rendered
        # under the image-input overload rather than its derivative profile.
        text = text.replace(description, "", 1)
        start = text.index(">Canny_Edges</h4>")
        paragraph = text.index("<p>", start)
        self.page.write_text(text[:paragraph] + "<p>" + description +
                             text[paragraph:], encoding="utf-8")
        _, missing, errors = check_site(self.site, ROOT)
        self.assertTrue(any("Derivative_X" in identity for identity in missing))
        self.assertTrue(any("does not render" in error for error in errors))

    def test_removing_a_rendered_description_is_detected(self):
        text = self.page.read_text(encoding="utf-8")
        start = text.index(">Gaussian_Blur</h4>")
        paragraph = text.index("<p>", start)
        end = text.index("<h5>", paragraph)
        self.page.write_text(text[:paragraph] + text[end:], encoding="utf-8")
        _, missing, errors = check_site(self.site, ROOT)
        self.assertIn(
            "OpenCV.Image_Processing: procedure Gaussian_Blur (Source : "
            "OpenCV.Core.Mat; Destination : in out OpenCV.Core.Mat; Kernel_Size : "
            "OpenCV.Size; Sigma : OpenCV.Float64_Value; Border : OpenCV.Border_Kind "
            ": = OpenCV.Reflect_101): description",
            set(missing) - set(self.missing))
        self.assertTrue(any("does not render" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
