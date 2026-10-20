"""Synthetic external-input controls: never AdaCore/Yocto qualification."""
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import test_cross_configuration as fixtures

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import adacore_cross as adapter


class ExternalInputTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CrossConfigurationTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.partial_fixture()
        self.env = dict(self.fixture.env)
        self.env.pop("OPENCV_CROSS_CORE_PREFIX")
        linker = self.fixture.base / "ld"
        linker.write_text("#!/bin/sh\necho synthetic-linker\n")
        linker.chmod(0o755)
        for name in ["ADA", "CXX"]:
            compiler = Path(self.env["OPENCV_CROSS_" + name])
            compiler.write_text(compiler.read_text().replace(
                "#!/bin/sh\n", f'#!/bin/sh\nif [ "$1" = -print-prog-name=ld ]; then echo {linker}; exit 0; fi\n'))
        self.provenance = self.fixture.base / "provenance.json"
        self.provenance.write_text(json.dumps(dict(release="scarthgap", build_identity="synthetic",
            image_identity="synthetic", export_method="synthetic", sysroot=str(self.fixture.sysroot))))
        self.env["OPENCV_CROSS_YOCTO_PROVENANCE"] = str(self.provenance)

    def check(self):
        with patch.dict(os.environ, self.env, clear=True):
            return adapter.preflight()

    def test_partial_never_promoted(self):
        result = self.check()
        self.assertFalse(result["production_qualified"])
        self.assertIn("CORE_PREREQUISITE_BLOCKED", result["dispositions"])
        self.assertFalse(any(item.endswith("_QUALIFIED") for item in result["dispositions"]))
        with self.assertRaisesRegex(adapter.cross.ConfigurationError, "partial sysroot"):
            adapter.cross.generate(result["target_inputs"], self.fixture.base / "new")

    def test_versions_may_differ_without_abi_claim(self):
        compiler = Path(self.env["OPENCV_CROSS_CXX"])
        compiler.write_text(compiler.read_text().replace("12.2.0", "14.1.0"))
        result = self.check()
        self.assertTrue(result["target_inputs"]["independent_toolchains"])
        self.assertIn("glibc/GLIBCXX/CXXABI requirements", result["unverified"])

    def test_missing_explicit_tools(self):
        for key in ["ADA", "CXX", "GPRBUILD", "GPRINSTALL"]:
            with self.subTest(key=key):
                name = "OPENCV_CROSS_" + key
                original = self.env[name]
                self.env[name] = "/nonexistent/adacore-tool"
                with self.assertRaisesRegex(adapter.cross.ConfigurationError, "unavailable"):
                    self.check()
                self.env[name] = original

    def test_flags_are_not_commands_or_search_overrides(self):
        for flag in ["--sysroot=/host", "-L/usr/lib", "-gnat2022", "-mabi=ilp32", "-mcpu=x;id", "-Wno-error"]:
            with self.subTest(flag=flag):
                self.env["OPENCV_CROSS_CXX_FLAGS"] = json.dumps([flag])
                with self.assertRaisesRegex(adapter.cross.ConfigurationError, "unsupported"):
                    self.check()

    def test_architecture_flags_recorded_not_qualified(self):
        self.env["OPENCV_CROSS_ADA_FLAGS"] = '["-mcpu=cortex-a53", "-mabi=lp64"]'
        self.assertEqual(self.check()["requested_flags"]["ada"], ["-mcpu=cortex-a53", "-mabi=lp64"])

    def test_provenance_is_required_and_bound_to_sysroot(self):
        original = self.provenance.read_text()
        for key, replacement in [("release", "kirkstone"), ("sysroot", "/host"),
                                  ("build_identity", ""), ("image_identity", ""), ("export_method", "")]:
            data = json.loads(original)
            data[key] = replacement
            self.provenance.write_text(json.dumps(data))
            with self.subTest(key=key), self.assertRaises(adapter.cross.ConfigurationError):
                self.check()
        self.provenance.unlink()
        with self.assertRaisesRegex(adapter.cross.ConfigurationError, "missing or invalid"):
            self.check()

    def test_wrong_gpr_configuration(self):
        self.fixture.config.write_text('for Target use "x86_64-linux-gnu";')
        with self.assertRaisesRegex(adapter.cross.ConfigurationError, "GPR target"):
            self.check()

    def test_missing_linker(self):
        (self.fixture.base / "ld").unlink()
        with self.assertRaisesRegex(adapter.cross.ConfigurationError, "linker unavailable"):
            self.check()

    def test_invalid_core_not_ignored(self):
        self.env["OPENCV_CROSS_CORE_PREFIX"] = str(self.fixture.core)
        (self.fixture.core / "include/opencv_core_module_bridge.hpp").unlink()
        with self.assertRaisesRegex(adapter.cross.ConfigurationError, "missing Core bridge"):
            self.check()


if __name__ == "__main__":
    unittest.main()