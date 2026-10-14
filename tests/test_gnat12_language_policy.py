"""Compile actual Imgproc units; these controls are not full library builds.

CORE_SOURCE must name the real selected Core checkout, never substitute specs.
ADA_COMPILER selects the compiler and its matching runtime. No ALIs are reused.
"""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get("CORE_SOURCE", ROOT.parent / "core")).resolve()


class LanguagePolicyTests(unittest.TestCase):
    def compile(self, unit, mode=None, representation=False):
        self.assertTrue((CORE / "src/opencv-core.ads").is_file(),
                        "CORE_SOURCE must contain actual production Core sources")
        with tempfile.TemporaryDirectory(prefix="imgproc-language-policy.") as output:
            command = [os.environ.get("ADA_COMPILER", "gcc-12"), "-c",
                       "-fPIC", "-gnatwa", "-gnatwe", "-Werror"]
            for directory in (ROOT / "src", ROOT / "src/internal",
                              CORE / "src", CORE / "src/internal"):
                command.append(f"-I{directory}")
            if mode:
                command.append(mode)
            if representation:
                command.append("-gnatR3")
            command.append(str(ROOT / "src" / unit))
            result = subprocess.run(command, cwd=output, text=True,
                                    capture_output=True)
            print("COMMAND:", " ".join(command), flush=True)
            print(result.stdout + result.stderr, end="", flush=True)
            return result

    def test_thick_body_default_and_ada2012(self):
        for mode in (None, "-gnat2012"):
            with self.subTest(mode=mode):
                result = self.compile("opencv-image_processing.adb", mode)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_forced_ada2022_is_not_the_native_policy(self):
        result = self.compile("opencv-image_processing.adb", "-gnat2022")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("array aggregate using ()", result.stderr)
        self.assertIn("opencv-image_processing.adb:90:", result.stderr)
        self.assertIn('ambiguous call to "Append"', result.stderr)

    def test_thin_body_and_actual_representations(self):
        for mode in (None, "-gnat2012", "-gnat2022"):
            with self.subTest(mode=mode):
                result = self.compile("internal/opencv-image_processing-internal-c_api.adb",
                                      mode, representation=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("Guil_Parameters", result.stdout)
                layouts = {
                    "Corner_Point": (64, 4), "Point_I32": (64, 4),
                    "Point_F32": (64, 4), "Contour_Span": (64, 4),
                    "Hough_Line_Evidence_Record": (192, 8),
                    "Hough_Circle_Evidence_Record": (128, 4),
                    "Hough_Line_Record": (64, 4),
                    "Hough_Segment_Record": (128, 4),
                    "Hough_Circle_Record": (96, 4),
                    "Hit_Or_Miss_Facts": (40, 1), "Scalar4": (256, 8),
                    "Rect_I32": (128, 4),
                    "Histogram_Dimension_Record": (128, 4),
                    "Histogram_Source_Dimension_Record": (160, 4),
                    "Histogram_Nonuniform_Dimension_Record": (192, 8),
                }
                for name, (bits, alignment) in layouts.items():
                    self.assertIn(f"for {name}'Size use {bits};", result.stdout)
                    self.assertIn(f"for {name}'Alignment use {alignment};", result.stdout)
                # Value_Size excludes tail padding; C sizeof is Object_Size.
                self.assertIn("for Guil_Parameters'Object_Size use 576;", result.stdout)
                self.assertIn("for Guil_Parameters'Alignment use 8;", result.stdout)
                self.assertIn("Boundary_Offset at 16 range  0 .. 63;", result.stdout)
                self.assertIn("for Hough_Circle_Record_Array'Component_Size use 96;",
                              result.stdout)
                self.assertIn("for Histogram_Nonuniform_Dimension_Records'Component_Size use 192;",
                              result.stdout)

    def test_cross_policy_preserves_native_language_selection(self):
        source = (ROOT / "scripts/cross_configuration.py").read_text()
        self.assertIn('Ada_Compiler_Switches := ("-gnatwa", "-gnatwe")', source)
        self.assertNotIn('Ada_Compiler_Switches := ("-gnat2022"', source)
        project = (ROOT / "opencv_imgproc.gpr").read_text()
        self.assertNotIn("-gnat2022", project)
        self.assertIn('("-Werror")', project)


if __name__ == "__main__":
    unittest.main()