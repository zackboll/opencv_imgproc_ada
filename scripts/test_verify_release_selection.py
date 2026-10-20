"""Positive and rejection controls for release lockfile selection auditing."""

import contextlib
import io
from pathlib import Path
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
        with self.assertRaises(AssertionError):
            self.check(version="0.5.1")

    def test_wrong_origin(self):
        with self.assertRaises(AssertionError):
            self.check(commit="0" * 40)

    def test_core_pin_rejected_even_for_test_crate(self):
        for allow in (False, True):
            with self.assertRaises(AssertionError):
                self.check(pinned=True, allow_parent=allow)

    def test_source_link_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "alire.lock"
            path.write_text('[[solution.state]]\ncrate = "opencv_core"\n'
                            'fulfilment = "linked"\n[solution.state.link]\n'
                            'path = ".."\n')
            with self.assertRaises(AssertionError):
                audit.verify(path, "0.5.0", allow_parent_pin=True)


if __name__ == "__main__":
    unittest.main()