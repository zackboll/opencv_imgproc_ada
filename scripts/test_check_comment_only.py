#!/usr/bin/env python3
"""Tests for the comment-only qualification check."""

import subprocess
import tempfile
import unittest
from pathlib import Path

from check_comment_only import compare, strip_comments

SPEC = (
    "package Demo is\n"
    "   --  Documentation.\n"
    "   Label : constant String := \"a -- b\";\n"
    "   Dash  : constant Character := '-';\n"
    "   procedure Run (Value : Integer := 1);  --  trailing\n"
    "end Demo;\n"
)


class StripCommentsTest(unittest.TestCase):
    def test_comments_and_layout_are_ignored(self):
        edited = SPEC.replace("   --  Documentation.\n",
                              "   --  New text.\n   --  @param Value Rewritten.\n")
        edited = edited.replace("(Value : Integer := 1);  --  trailing",
                                "\n     (Value : Integer := 1);")
        self.assertEqual(strip_comments(SPEC), strip_comments(edited))

    def test_string_contents_are_code(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace('"a -- b"', '"a -- c"')))

    def test_character_literal_is_code(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace("'-'", "'+'")))

    def test_declaration_change_is_detected(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace(":= 1", ":= 2")))


class RepositoryCompareTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "src").mkdir()
        self.spec = self.root / "src/demo.ads"
        self.spec.write_text(SPEC, encoding="utf-8")
        for command in (["init", "-q"], ["add", "src"],
                        ["-c", "user.name=t", "-c", "user.email=t@example.com",
                         "commit", "-q", "-m", "base"]):
            subprocess.run(["git", "-C", str(self.root), *command], check=True)

    def tearDown(self):
        self.temporary.cleanup()

    def test_comment_edit_passes_and_code_edit_fails(self):
        self.spec.write_text(SPEC.replace("Documentation.", "Better words."),
                             encoding="utf-8")
        self.assertEqual(compare("HEAD", self.root), [])
        self.spec.write_text(SPEC.replace("Integer := 1", "Natural := 1"),
                             encoding="utf-8")
        self.assertEqual(compare("HEAD", self.root), ["code changed: src/demo.ads"])

    def test_added_source_is_reported(self):
        (self.root / "src/extra.ads").write_text("package Extra is\nend Extra;\n",
                                                encoding="utf-8")
        self.assertEqual(compare("HEAD", self.root), ["added: src/extra.ads"])


if __name__ == "__main__":
    unittest.main()
