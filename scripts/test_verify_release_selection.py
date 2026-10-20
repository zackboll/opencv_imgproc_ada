"""Positive and rejection controls for release lockfile selection auditing."""

import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import verify_release_selection as audit


class SelectionTests(unittest.TestCase):
    def check(self, *, version="0.5.0", commit=audit.CORE_050,
              pinned=False, name="opencv_core", allow_parent=False):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "alire.lock"
            path.write_text(
                '[[solution.state]]\ncrate = "' + name + '"\n'
                'fulfilment = "solved"\npinned = ' + str(pinned).lower() + '\n'
                '[solution.state.release]\nversion = "' + version + '"\n'
                '[solution.state.release.origin]\ncommit = "' + commit + '"\n'
                'url = "' + audit.CORE_URL + '"\n')
            with contextlib.redirect_stdout(io.StringIO()):
                audit.verify(path, "0.5.0", allow_parent_pin=allow_parent)

    def test_actual_minimum(self):
        self.check()

    def test_later_compatible_version_is_not_minimum(self):
        with self.assertRaises(ValueError):
            self.check(version="0.5.1")

    def test_wrong_origin(self):
        with self.assertRaises(ValueError):
            self.check(commit="0" * 40)

    def test_core_pin_rejected_even_for_test_crate(self):
        for allow in (False, True):
            with self.assertRaises(ValueError):
                self.check(pinned=True, allow_parent=allow)

    def test_source_link_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "alire.lock"
            path.write_text('[[solution.state]]\ncrate = "opencv_core"\n'
                            'fulfilment = "linked"\n[solution.state.link]\n'
                            'path = ".."\n')
            with self.assertRaises(ValueError):
                audit.verify(path, "0.5.0", allow_parent_pin=True)


class SubprocessTests(unittest.TestCase):
    """Exercise CLI rejections even when Python assertions are disabled."""

    imgproc_commit = "1" * 40
    pass_message = "PASS release selection and immutable origins:"

    def selection(self, name, version, commit, url):
        return (f'[[solution.state]]\ncrate = "{name}"\n'
                'fulfilment = "solved"\npinned = false\n'
                f'[solution.state.release]\nversion = "{version}"\n'
                f'[solution.state.release.origin]\ncommit = "{commit}"\n'
                f'url = "{url}"\n')

    def campaign(self, optimized=False, inherited=False):
        core = self.selection("opencv_core", "0.5.0", audit.CORE_050,
                              audit.CORE_URL)
        imgproc = self.selection("opencv_imgproc", "0.3.0",
                                 self.imgproc_commit, audit.IMGPROC_URL)
        parent = ('[[solution.state]]\ncrate = "opencv_imgproc"\n'
                  'fulfilment = "linked"\npinned = false\n'
                  '[solution.state.link]\npath = ".."\n')
        invalid = {
            "core pin": core.replace(
                "pinned = false", "pinned = true") + imgproc,
            "core version": core.replace("0.5.0", "0.5.1") + imgproc,
            "core commit": core.replace(audit.CORE_050, "0" * 40) + imgproc,
            "core repository": core.replace(
                audit.CORE_URL, "git+https://invalid/core") + imgproc,
            "combined invalid core": self.selection(
                "opencv_core", "9.9.9", "0" * 40, "git+https://invalid/core"
            ).replace("pinned = false", "pinned = true") + imgproc,
            "unsolved": core.replace('"solved"', '"missing"') + imgproc,
            "missing core": imgproc,
            "missing imgproc": core,
            "imgproc version": core + imgproc.replace("0.3.0", "0.2.1"),
            "imgproc commit": core + imgproc.replace(
                self.imgproc_commit, "0" * 40),
            "imgproc repository": core + imgproc.replace(
                audit.IMGPROC_URL, audit.CORE_URL),
            "imgproc pin": core + imgproc.replace(
                "pinned = false", "pinned = true"),
            "malformed": "not valid TOML",
        }
        cases = [("valid", core + imgproc, False, True, True),
                 ("ordinary resolution", core + imgproc, False, False, True),
                 ("parent allowed", core + parent, True, False, True),
                 ("existing Imgproc pin exception", invalid["imgproc pin"],
                  True, True, True),
                 ("parent forbidden", core + parent, False, False, False),
                 ("wrong parent", core + parent.replace('".."', '"../other"'),
                  True, False, False),
                 ("core link", parent.replace("opencv_imgproc", "opencv_core"),
                  True, False, False)]
        cases.extend((name, text, False, True, False)
                     for name, text in invalid.items())
        # The exception must never authorize a Core pin, even with the flag.
        cases.append(("core pin with parent exception", invalid["core pin"],
                      True, True, False))
        env = dict(os.environ)
        env.pop("PYTHONOPTIMIZE", None)
        if inherited:
            env["PYTHONOPTIMIZE"] = "1"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "alire.lock"
            for name, text, allow_parent, check_imgproc, valid in cases:
                with self.subTest(selection=name):
                    path.write_text(text)
                    command = [sys.executable]
                    if optimized:
                        command.append("-O")
                    command.extend([str(Path(audit.__file__).resolve()),
                                    str(path), "--core-version", "0.5.0"])
                    if check_imgproc:
                        command.extend(["--imgproc-commit",
                                        self.imgproc_commit])
                    if allow_parent:
                        command.append("--allow-parent-pin")
                    result = subprocess.run(
                        command, env=env, capture_output=True,
                        text=True, timeout=15)
                    if valid:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn(self.pass_message, result.stdout)
                        self.assertEqual(result.stderr, "")
                    else:
                        self.assertNotEqual(result.returncode, 0,
                                            result.stdout)
                        self.assertNotIn(self.pass_message, result.stdout)
                        self.assertIn("error: invalid release selection:",
                                      result.stderr)

    def test_normal_python(self):
        self.campaign()

    def test_python_O(self):
        self.campaign(optimized=True)

    def test_inherited_PYTHONOPTIMIZE(self):
        self.campaign(inherited=True)


if __name__ == "__main__":
    unittest.main()