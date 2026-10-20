"""Focused installation/isolation controls; synthetic, not vendor evidence."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import cross_configuration as cross
import cross_install_imgproc as installer
import cross_support as support
import test_cross_configuration as fixtures
sys.path.insert(0, str(Path(__file__).resolve().parent / "cross"))
import stage_debian_alternatives


class InstalledCoreTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CrossConfigurationTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)

    def test_core_outside_sysroot_without_invented_attestation(self):
        fixture = self.fixture
        outside = fixture.base / "external-core"
        shutil.move(fixture.core, outside)
        fixture.env["OPENCV_CROSS_CORE_PREFIX"] = str(outside)
        (outside / "share/opencv_core/cross-identity.json").unlink()
        result = fixture.check()
        self.assertEqual(result["core"], str(outside))
        self.assertEqual(result["core_provenance"], {})

    def test_equivalent_config_does_not_require_raw_hash_equality(self):
        self.fixture.config.write_text(self.fixture.config.read_text().replace(
            'Target use "aarch64-linux-gnu"', 'Target use "aarch64-linux"') + "-- equivalent\n")
        self.fixture.check()


class CrossInstallTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="imgproc-install-controls-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_debian_alternatives_parse_literal_metadata_not_shell(self):
        metadata = ('update-alternatives --install /usr/lib/aarch64-linux-gnu/liblapack.so.3 lapack '
                    '/usr/lib/aarch64-linux-gnu/lapack/liblapack.so.3 10\n'
                    'update-alternatives --install /tmp/escape.so.3 escape /tmp/source 50\n')
        self.assertEqual(stage_debian_alternatives.alternatives(metadata), [
            ('/usr/lib/aarch64-linux-gnu/liblapack.so.3',
             '/usr/lib/aarch64-linux-gnu/lapack/liblapack.so.3', '10')])

    def test_conflict_preflight_does_not_publish_or_replace_core(self):
        staged, prefix = self.root / "stage", self.root / "prefix"
        for root in [staged, prefix]:
            (root / "share/gpr").mkdir(parents=True)
        (staged / "a-first.txt").write_text("must not be published")
        (staged / "share/gpr/opencv_core.gpr").write_text("wrong")
        core = prefix / "share/gpr/opencv_core.gpr"
        core.write_text("authentic Core")
        before = installer.inventory(prefix)
        with self.assertRaisesRegex(cross.ConfigurationError, "conflict"):
            installer.publish(staged, prefix)
        self.assertEqual(before, installer.inventory(prefix))
        self.assertFalse((prefix / "a-first.txt").exists())

    def test_shared_prefix_preserves_all_existing_core_bytes(self):
        stage, prefix = self.root / "stage", self.root / "shared"
        (prefix / "share/gprconfig").mkdir(parents=True)
        (prefix / "share/gprconfig/core.cgpr").write_bytes(b"core config\x00")
        before = installer.inventory(prefix)
        (stage / "share/gprconfig").mkdir(parents=True)
        (stage / "share/gprconfig/imgproc.cgpr").write_text("durable")
        installer.publish(stage, prefix)
        shutil.rmtree(stage)
        installer.preserve(before, prefix)
        self.assertEqual((prefix / "share/gprconfig/imgproc.cgpr").read_text(), "durable")

    def test_publication_symlink_escape(self):
        stage, prefix, outside = self.root / "stage", self.root / "prefix", self.root / "outside"
        (stage / "share").mkdir(parents=True)
        (stage / "share/file").touch()
        prefix.mkdir()
        outside.mkdir()
        (prefix / "share").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(cross.ConfigurationError, "symlink"):
            installer.publish(stage, prefix)
        self.assertEqual(list(outside.iterdir()), [])

    def test_prefixes_separate_or_equal_not_nested(self):
        source, sysroot, core = [self.root / name for name in ["source", "sysroot", "core"]]
        for path in [source, sysroot, core]:
            path.mkdir()
        for prefix in [core, self.root / "imgproc"]:
            self.assertEqual(installer.prefix_safety(prefix, source, sysroot, core), prefix)
        for prefix in [core / "nested", source / "nested", sysroot / "nested", self.root]:
            with self.assertRaises(cross.ConfigurationError):
                installer.prefix_safety(prefix, source, sysroot, core)

    def test_logged_original_exit_status_and_retained_diagnostics(self):
        log = self.root / "failure.log"
        with self.assertRaises(cross.ConfigurationError) as raised:
            cross.logged(["sh", "-c", "printf 'specific failure'; exit 37"], log, dict(os.environ))
        self.assertEqual(raised.exception.returncode, 37)
        self.assertEqual(log.read_text(), "specific failure")
        with self.assertRaises(cross.ConfigurationError) as raised:
            cross.run(["sh", "-c", "exit 42"])
        self.assertEqual(raised.exception.returncode, 42)

    def test_complete_vendor_ali_signature_not_gcc_major(self):
        ali = self.root / "probe.ali"
        ali.write_text('V "GNAT Lib v25.0w"\n')
        self.assertEqual(support.ali_signature(ali), 'V "GNAT Lib v25.0w"')
        support.check_alis(self.root, 'V "GNAT Lib v25.0w"')
        with self.assertRaisesRegex(cross.ConfigurationError, "mixed GNAT"):
            support.check_alis(self.root, 'V "GNAT Lib v12"')

    def test_fresh_probe_compares_actual_runtime_signature(self):
        runtime = self.root / "runtime"
        (runtime / "adalib").mkdir(parents=True)
        (runtime / "adalib/system.ali").write_text('V "GNAT Lib v25.0w"\n')
        (runtime / "adalib/libgnat.a").touch()
        compiler = self.root / "gcc"
        compiler.touch()
        def compile_probe(arguments, log, environment):
            obj = Path(arguments[-1])
            obj.touch()
            obj.with_suffix(".ali").write_text('V "GNAT Lib v25.0w"\n')
            log.write_text("actual selected compile\n")
        with patch.object(cross, "logged", side_effect=compile_probe), patch.object(cross, "elf"):
            result = support.identity_probe(str(compiler), runtime, "readelf")
        self.assertEqual(result["signature"], 'V "GNAT Lib v25.0w"')
        self.assertIn("actual selected", result["compile_log"])

    def test_actual_linker_input_rejects_foreign_object(self):
        foreign = self.root / "foreign.o"
        foreign.write_bytes(b"\x7fELFfake")
        log = self.root / "link.log"
        log.write_text(str(foreign) + "\n")
        settings = dict(cxx="/tools/target-g++", sysroot=str(self.root / "sysroot"),
                        runtime=str(self.root / "runtime"), readelf="readelf")
        with patch.object(cross, "run", return_value="unresolved"):
            with self.assertRaisesRegex(cross.ConfigurationError, "unapproved actual linker"):
                support.link_inputs(log, settings, self.root / "work")

    def test_gnatls_unresolved_adalib_checks_complete_search_sections(self):
        runtime = self.root / "runtime"
        for name in ["adainclude", "adalib"]:
            (runtime / name).mkdir(parents=True)
        gcc, gnatls = self.root / "aarch64-linux-gnu-gcc", self.root / "aarch64-linux-gnu-gnatls"
        gcc.touch()
        gnatls.touch()
        gnatls.chmod(0o755)
        output = (f"Source Search Path:\n <Current_Directory>\n {runtime}/adainclude\n"
                  f"Object Search Path:\n <Current_Directory>\n {runtime}/adalib\nProject Search Path:\n /irrelevant\n")
        with patch.object(cross, "run", side_effect=["adalib", output]):
            self.assertEqual(support.runtime_identity(str(gcc), runtime)["method"], "gnatls")
        for bad in [output.replace("Object Search Path:", "Other Search Path:"),
                    output.replace(" <Current_Directory>", f" {self.root}", 1),
                    output.replace(f" {runtime}/adalib", " relative/adalib")]:
            with patch.object(cross, "run", side_effect=["adalib", bad]):
                with self.assertRaises(cross.ConfigurationError):
                    support.runtime_identity(str(gcc), runtime)

    def test_git_free_staging_is_explicit_deterministic_and_sanitized(self):
        source = self.root / "release"
        source.mkdir()
        (source / "alire.toml").write_text('name = "opencv_imgproc"\n')
        (source / "src").mkdir()
        (source / "src/source.ads").write_text("package Source is end Source;\n")
        for name in ["config", "obj", "alire"]:
            (source / name).mkdir()
            (source / name / "stale").touch()
        (source / "src/stale.ali").touch()
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(cross.ConfigurationError, "explicit"):
                support.export_source(source, self.root / "refused")
        with patch.dict(os.environ, {"OPENCV_CROSS_SOURCE_ROOT": str(source)}):
            first = support.export_source(source, self.root / "first")
            second = support.export_source(source, self.root / "second")
        self.assertEqual(first, second)
        self.assertTrue(first.startswith("staged-sha256:"))
        self.assertFalse((self.root / "first/src/stale.ali").exists())
        self.assertFalse((self.root / "first/obj").exists())

    def test_exact_consumer_library_allowance_recomputed_for_relocation(self):
        settings = dict(ada="/tools/aarch64-linux-gnu-gcc", cxx="/tools/aarch64-linux-gnu-g++",
                        target="aarch64-linux-gnu", sysroot=str(self.root / "sysroot"),
                        runtime=str(self.root / "runtime"), core=str(self.root / "core"))
        log = self.root / "trace.log"
        for spelling in ["installed", "relocated"]:
            library = self.root / spelling / "lib/opencv_imgproc"
            library.mkdir(parents=True)
            log.write_text(settings["ada"] + " -c source.adb -L" + str(library) + "\n")
            self.assertEqual(support.check_trace(log, settings, [library])["compilations"], 1)
            with self.assertRaisesRegex(cross.ConfigurationError, "unapproved"):
                support.check_trace(log, settings)
            for bad in [str(library) + "/nested", str(library) + "-sibling", str(library) + "/../opencv_imgproc",
                        "/usr/local/lib", "-I" + str(library)]:
                flag = bad if bad.startswith("-I") else "-L" + bad
                log.write_text(settings["ada"] + " -c source.adb " + flag + "\n")
                with self.assertRaisesRegex(cross.ConfigurationError, "unapproved"):
                    support.check_trace(log, settings, [library])


if __name__ == "__main__":
    unittest.main()