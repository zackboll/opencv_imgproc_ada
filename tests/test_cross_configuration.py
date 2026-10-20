"""Negative-first synthetic controls, explicitly not target compiler evidence."""
import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import cross_configuration as cross


class CrossConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="imgproc-cross-negative.")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        probe = patch.object(cross.support, "identity_probe", return_value={"signature": 'V "GNAT Lib v12"'})
        probe.start()
        self.addCleanup(probe.stop)
        self.sysroot = self.base / "sysroot"
        self.include = self.sysroot / "usr/include/opencv4/opencv2"
        self.library = self.sysroot / "usr/lib"
        self.runtime = self.base / "runtime"
        self.core = self.sysroot / "opt/core"
        for directory in [self.include / "core", self.library / "pkgconfig",
                          self.runtime / "adalib", self.runtime / "adainclude",
                          self.core / "share/gpr", self.core / "include",
                          self.core / "lib/opencv_core", self.core / "lib/opencv_core_shim",
                          self.core / "share/opencv_core"]:
            directory.mkdir(parents=True)
        for path in [self.include / "core.hpp", self.include / "imgproc.hpp",
                     self.library / "libopencv_core.so", self.library / "libopencv_imgproc.so",
                     self.library / "libc.so.6", self.library / "libstdc++.so.6",
                     self.runtime / "adalib/libgnat.a", self.core / "lib/opencv_core/libopencv_core_ada.a",
                     self.core / "lib/opencv_core_shim/libopencv_core_shim.a",
                     self.core / "include/opencv_core_module_bridge.hpp"]:
            path.touch()
        (self.runtime / "adalib/system.ali").write_text('V "GNAT Lib v12"\n')
        (self.include / "core/version.hpp").write_text(
            "#define CV_VERSION_MAJOR 4\n#define CV_VERSION_MINOR 6\n#define CV_VERSION_REVISION 0\n")
        (self.core / "share/gpr/opencv_core.gpr").write_text(
            'with "opencv_core_shim";\nfor Externally_Built use "true";\n')
        (self.core / "share/gpr/opencv_core_shim.gpr").write_text('for Externally_Built use "true";\n')
        (self.core / "lib/opencv.ali").write_text('V "GNAT Lib v12"\n')
        self.env = {"PATH": os.environ["PATH"], "OPENCV_CROSS_TARGET": "aarch64-linux-gnu",
                    "ENV_PREFIX": str(self.sysroot), "OPENCV_CROSS_RUNTIME": str(self.runtime),
                    "PKG_CONFIG_LIBDIR": str(self.library / "pkgconfig"),
                    "OPENCV_CROSS_CORE_PREFIX": str(self.core)}

        def executable(name, body):
            path = self.base / name
            path.write_text("#!/bin/sh\n" + body)
            path.chmod(0o755)
            return str(path)

        self.env["OPENCV_CROSS_ADA"] = executable("ada", f'case "$1" in\n'
            f'-print-file-name=adalib) echo {self.runtime}/adalib ;;\n'
            '-dumpfullversion) echo 12.2.0 ;;\n*) echo aarch64-linux-gnu ;;\nesac\n')
        self.env["OPENCV_CROSS_CXX"] = executable("cxx", 'echo aarch64-linux-gnu\n')
        self.env["OPENCV_CROSS_READELF"] = executable("readelf",
            'case "$1" in -d) printf "%s\\n" "(SONAME) [libopencv_core.so.406]" "(SONAME) [libopencv_imgproc.so.406]" ;;\n'
            '*) printf "%s\\n" "Class: ELF64" "Machine: AArch64" '
            '"Data: 2\x27s complement, little endian" ;;\nesac\n')
        self.env["OPENCV_CROSS_PKG_CONFIG"] = executable("pkg-config",
            'case "$1" in --exists) exit 0 ;; --modversion) echo 4.6.0 ;;\n'
            '--variable=includedir) echo /usr/include/opencv4 ;;\n'
            '--variable=libdir) echo /usr/lib ;;\nesac\n')
        self.env["OPENCV_CROSS_GPRBUILD"] = executable("gprbuild", 'exit 0\n')
        self.env["OPENCV_CROSS_GPRINSTALL"] = executable("gprinstall", 'exit 0\n')
        self.config = self.base / "target.cgpr"
        self.config.write_text('for Target use "aarch64-linux-gnu";\n'
            f'for Driver ("Ada") use "{self.env["OPENCV_CROSS_ADA"]}";\n'
            f'for Driver ("C++") use "{self.env["OPENCV_CROSS_CXX"]}";\n'
            f'for Runtime ("Ada") use "{self.runtime}/";\n'
            'package Binder is end Binder;\npackage Linker is end Linker;\n')
        self.env["OPENCV_CROSS_GPR_CONFIG"] = str(self.config)
        self.identity = self.core / "share/opencv_core/cross-identity.json"
        self.identity.write_text(json.dumps(dict(target="aarch64-linux-gnu", runtime=str(self.runtime),
            opencv_version="4.6.0", ada_version="12.2.0", gpr_config_sha256=cross.digest(self.config),
            library_kind="static-pic", source_sha="a" * 40)))

    def check(self):
        with patch.dict(os.environ, self.env, clear=True):
            return cross.validate()

    def reject(self, message):
        before = sorted(str(p) for p in self.base.rglob("*"))
        with self.assertRaisesRegex(cross.ConfigurationError, message):
            self.check()
        self.assertEqual(before, sorted(str(p) for p in self.base.rglob("*")))

    def test_valid_preflight_repeatable(self):
        self.assertEqual(self.check(), self.check())

    def test_missing_inputs(self):
        for key in ["OPENCV_CROSS_TARGET", "ENV_PREFIX", "OPENCV_CROSS_ADA",
                    "OPENCV_CROSS_CXX", "OPENCV_CROSS_RUNTIME", "OPENCV_CROSS_GPR_CONFIG",
                    "OPENCV_CROSS_PKG_CONFIG", "PKG_CONFIG_LIBDIR", "OPENCV_CROSS_CORE_PREFIX",
                    "OPENCV_CROSS_GPRBUILD", "OPENCV_CROSS_GPRINSTALL"]:
            with self.subTest(key=key):
                item = self.env.pop(key)
                self.reject(key)
                self.env[key] = item

    def test_target_names(self):
        for target in ["aarch64-linux-gnu", "aarch64-unknown-linux-gnu", "aarch64-poky-linux",
                       "aarch64-poky-linux-gnu", "aarch64-linux-musl"]:
            result = subprocess.run(["sh", str(ROOT / "scripts/validate_cross_target.sh"), target])
            self.assertEqual(result.returncode, 0)
        self.env["OPENCV_CROSS_TARGET"] = "x86_64-linux-gnu"
        self.reject("AArch64 Linux")

    def test_compiler_mismatch(self):
        for key in ["OPENCV_CROSS_ADA", "OPENCV_CROSS_CXX"]:
            path = Path(self.env[key])
            original = path.read_text()
            path.write_text("#!/bin/sh\necho x86_64-linux-gnu\n")
            self.reject("compiler target mismatch")
            path.write_text(original)

    def test_missing_runtime(self):
        (self.runtime / "adalib/libgnat.a").unlink()
        self.reject("missing or invalid")

    def test_wrong_runtime(self):
        path = Path(self.env["OPENCV_CROSS_ADA"])
        path.write_text(path.read_text().replace(str(self.runtime / "adalib"), str(self.library)))
        self.reject("runtime differs")

    def test_gpr_target_compilers_runtime_linker(self):
        original = self.config.read_text()
        for token, message in [("aarch64-linux-gnu", "GPR target"),
                (self.env["OPENCV_CROSS_ADA"], "GPR Ada compiler"),
                (self.env["OPENCV_CROSS_CXX"], "GPR C\\+\\+ compiler"),
                (str(self.runtime), "GPR Ada runtime"), ("package Linker", "GPR binder/linker")]:
            self.config.write_text(original.replace(token, "WRONG"))
            self.reject(message)
        self.config.write_text(original)

    def test_gpr_comments_not_evidence(self):
        self.config.write_text("\n".join("-- " + line for line in self.config.read_text().splitlines()))
        self.reject("GPR target")

    def test_host_search_environment(self):
        for key in ["CPATH", "LIBRARY_PATH", "GPR_PROJECT_PATH", "ADA_OBJECTS_PATH",
                    "CPLUS_INCLUDE_PATH", "COMPILER_PATH", "ADA_INCLUDE_PATH"]:
            self.env[key] = "/host"
            self.reject(key)
            del self.env[key]

    def test_host_pkg_config(self):
        self.env["PKG_CONFIG_LIBDIR"] = str(self.base)
        self.reject("escapes sysroot")

    def test_empty_pkg_component(self):
        self.env["PKG_CONFIG_LIBDIR"] += ":"
        self.reject("required|empty pkg")

    def test_pkg_config_path(self):
        self.env["PKG_CONFIG_PATH"] = "/host"
        self.reject("PKG_CONFIG_PATH")

    def test_pkg_sysroot(self):
        self.env["PKG_CONFIG_SYSROOT_DIR"] = "/host"
        self.reject("sysroot mismatch")

    def test_host_flags_and_libraries(self):
        pkg = Path(self.env["OPENCV_CROSS_PKG_CONFIG"])
        original = pkg.read_text()
        for flag in ["-I" + str(self.base), "-L" + str(self.base), str(self.base / "ada"), "-Wl,-rpath,/host"]:
            pkg.write_text(original.replace('--exists)', f'--cflags) echo {flag} ;; --exists)'))
            self.reject("escapes sysroot|unsupported")
        pkg.write_text(original)

    def test_missing_headers_and_libraries(self):
        for path in [self.include / "core.hpp", self.include / "imgproc.hpp",
                     self.library / "libopencv_core.so", self.library / "libopencv_imgproc.so",
                     self.core / "include/opencv_core_module_bridge.hpp"]:
            path.unlink()
            self.reject("missing")
            path.touch()

    def test_mixed_architecture_endian_class(self):
        reader = Path(self.env["OPENCV_CROSS_READELF"])
        original = reader.read_text()
        for bad in ["Machine: X86-64", "Data: 2's complement, big endian", "Class: ELF32"]:
            reader.write_text(original + f'case "$2" in *libopencv_imgproc*) echo "{bad}" ;; esac\n')
            self.reject("not ELF64")
        reader.write_text(original)

    def test_escaping_and_broken_symlinks(self):
        for path in [self.include / "detail.hpp", self.library / "pkgconfig/escape.pc",
                     self.core / "include/escape.hpp"]:
            for target in [self.base / "ada", self.base / "absent"]:
                path.symlink_to(target)
                self.reject("escapes sysroot|missing or invalid")
                path.unlink()

    def test_symlink_cycle(self):
        (self.include / "loop").symlink_to(self.include)
        self.reject("invalid target tree")

    def test_local_header_alias(self):
        (self.include / "alias.hpp").symlink_to(self.include / "core.hpp")
        self.check()

    def test_library_symlink_escape(self):
        path = self.library / "libopencv_imgproc.so"
        path.unlink()
        path.symlink_to(self.base / "ada")
        self.reject("escapes sysroot")

    def test_version_mismatch(self):
        (self.include / "core/version.hpp").write_text("#define CV_VERSION_MAJOR 5\n")
        self.reject("version mismatch")

    def test_soname_mismatch(self):
        reader = Path(self.env["OPENCV_CROSS_READELF"])
        reader.write_text(reader.read_text().replace("imgproc.so.406", "imgproc.so.410"))
        self.reject("SONAME/version mismatch")

    def test_missing_core_project_identity_alis(self):
        for path in [self.core / "share/gpr/opencv_core.gpr", self.core / "lib/opencv.ali"]:
            data = path.read_text()
            path.unlink()
            self.reject("missing")
            path.write_text(data)

    def test_core_identity_contamination(self):
        original = self.identity.read_text()
        for key in ["runtime", "target", "opencv_version", "ada_version", "library_kind"]:
            data = json.loads(original)
            data[key] = "wrong"
            self.identity.write_text(json.dumps(data))
            self.reject("identity mismatch|invalid Core source")
        self.identity.write_text(original)

    def test_mixed_gnat_ali(self):
        (self.core / "lib/opencv.ali").write_text('V "GNAT Lib v16.1.0"\n')
        self.reject("mixed GNAT")

    def test_core_project_host_paths_and_imports(self):
        project = self.core / "share/gpr/opencv_core.gpr"
        original = project.read_text()
        for extra in [f'for Library_Dir use "{self.base}";',
                      'with "../../../../../../host.gpr";']:
            project.write_text(original + extra)
            self.reject("escapes sysroot|missing or invalid|outside validated roots")
        project.write_text(original)

    def test_exact_revision_workspace_and_recreation(self):
        # Fake tool outputs here qualify isolation only, never TARGET_PROBE.
        settings = self.check()
        checkout = self.base / "checkout"
        checkout.mkdir()
        for relative in ["scripts/validate_cross_target.sh", "opencv_imgproc_shim.gpr",
                         "tests/fixtures/cross-reference/probe.adb",
                         "tests/fixtures/cross-reference/cxx_probe.cpp",
                         "tests/fixtures/cross-reference/probe.gpr"]:
            source = ROOT / relative
            target = checkout / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        subprocess.run(["git", "init", "-q", str(checkout)], check=True)
        subprocess.run(["git", "-C", str(checkout), "add", "."], check=True)
        subprocess.run(["git", "-C", str(checkout), "-c", "user.name=Fixture",
                        "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture"], check=True)
        compiler = Path(settings["gprbuild"])
        compiler.write_text('#!/bin/sh\nfor arg do\ncase "$arg" in *.gpr) project=$arg ;; esac\ndone\n'
            'base=$(dirname "$project")\nmkdir -p "$base/bin" "$base/obj"\n'
            'touch "$base/bin/probe" "$base/obj/cxx_probe.o"\n'
            f'echo "{settings["ada"]} {settings["cxx"]}"\n')
        destination = self.base / "export"
        revision = cross.run(["git", "-C", str(checkout), "rev-parse", "HEAD"])
        import shutil
        with patch.object(cross, "ROOT", checkout), patch.object(cross.support, "check_trace"), \
                patch.object(cross.support, "link_inputs"), \
                patch.object(cross.support, "executable_evidence", return_value={}), patch.dict(os.environ, self.env, clear=True):
            for _ in range(2):
                with contextlib.redirect_stdout(io.StringIO()):
                    cross.workspace("--prepare", str(destination), settings)
                self.assertEqual((destination / "source-revision.txt").read_text().strip(), revision)
                self.assertTrue((destination / "config/target.cgpr").is_file())
                self.assertFalse((checkout / "config").exists())
                self.assertEqual(cross.run(["git", "-C", str(checkout), "status", "--porcelain"]), "")
                with self.assertRaisesRegex(cross.ConfigurationError, "already exist"):
                    cross.workspace("--prepare", str(destination), settings)
                shutil.rmtree(destination)

    def test_workspace_rejections_before_mutation(self):
        settings = self.check()
        alias = self.base / "alias"
        alias.symlink_to(ROOT)
        dangling = self.base / "dangling"
        dangling.symlink_to(self.base / "missing")
        for path in ["relative", str(self.base), str(ROOT / "new"), str(self.sysroot / "new"),
                     str(alias / "new"), str(dangling)]:
            before = sorted(str(p) for p in self.base.rglob("*"))
            with self.assertRaisesRegex(cross.ConfigurationError, "workspace"):
                cross.workspace("--prepare", path, settings)
            self.assertEqual(before, sorted(str(p) for p in self.base.rglob("*")))

    def test_native_configuration_preserved(self):
        config = ROOT / "config"
        before = {p: p.read_bytes() for p in config.glob("*")} if config.exists() else {}
        self.check()
        # Exercise a read-only partial check in a subprocess; fake compilers do
        # not stand in for the separately tested real fresh-ALI probe.
        self.partial_fixture()
        result = subprocess.run(["sh", str(ROOT / "scripts/configure_cross_opencv.sh"), "--check-sysroot"],
            env=dict(self.env, OPENCV_IMGPROC_CROSS="True"), cwd=ROOT, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, {p: p.read_bytes() for p in config.glob("*")} if config.exists() else {})

    def test_source_configuration_generation_rejected(self):
        with self.assertRaisesRegex(cross.ConfigurationError, "isolated"):
            cross.generate(self.check(), ROOT)

    def test_partial_cannot_authorize_workspace(self):
        with self.assertRaisesRegex(cross.ConfigurationError, "partial sysroot"):
            cross.workspace("--build", str(self.base / "new"),
                            {"qualification": "TARGET_SYSROOT_ONLY"})

    def partial_fixture(self):
        """Synthetic partial-gate fixture, never target integration evidence."""
        (self.library / "libgcc.a").touch()
        (self.library / "libstdc++.so").touch()
        pkg = Path(self.env["OPENCV_CROSS_PKG_CONFIG"])
        pkg.write_text(pkg.read_text().replace('--exists)',
            f'--cflags) case "$2" in --libs) echo -I{self.include.parent} -lopencv_core -lopencv_imgproc ;; *) echo -I{self.include.parent} ;; esac ;; '
            '--libs) echo -lopencv_core -lopencv_imgproc ;; '
            f'--variable=pcfiledir) echo {self.library}/pkgconfig ;; --exists)'))
        pkg.write_text(pkg.read_text().replace('--exists) exit 0',
                                             '--exists) test "$2" = opencv4; exit $?'))
        (self.library / "pkgconfig/opencv4.pc").write_text("# synthetic negative-control metadata\n")
        cxx = Path(self.env["OPENCV_CROSS_CXX"])
        cxx.write_text('#!/bin/sh\ncase "$*" in *libgcc.a*) '
            f'echo {self.library}/libgcc.a ;; *libstdc++.so*) echo {self.library}/libstdc++.so ;; '
            '*dumpfullversion*) echo 12.2.0 ;; *) echo aarch64-linux-gnu ;; esac\n')
        reader = Path(self.env["OPENCV_CROSS_READELF"])
        reader.write_text(reader.read_text().replace('case "$1" in',
            'case "$1" in --version-info) echo GLIBCXX_3.4.30 ;;'))

    def partial_check(self):
        with patch.dict(os.environ, self.env, clear=True):
            return cross.validate(sysroot_only=True)

    def test_partial_requires_real_metadata_location(self):
        self.partial_fixture()
        self.assertFalse(self.partial_check()["production_qualified"])
        (self.library / "pkgconfig/opencv4.pc").unlink()
        with self.assertRaisesRegex(cross.ConfigurationError, "missing or invalid"):
            self.partial_check()

    def test_partial_wrong_gcc_gnat_version(self):
        self.partial_fixture()
        cxx = Path(self.env["OPENCV_CROSS_CXX"])
        cxx.write_text(cxx.read_text().replace('12.2.0', '13.1.0'))
        with self.assertRaisesRegex(cross.ConfigurationError, "GCC/GNAT"):
            self.partial_check()

    def test_partial_missing_required_metadata_flags(self):
        self.partial_fixture()
        pkg = Path(self.env["OPENCV_CROSS_PKG_CONFIG"])
        pkg.write_text(pkg.read_text().replace('-lopencv_imgproc', ''))
        with self.assertRaisesRegex(cross.ConfigurationError, "lacks required"):
            self.partial_check()

    def test_partial_cannot_generate(self):
        with self.assertRaisesRegex(cross.ConfigurationError, "partial sysroot"):
            cross.generate({"qualification": "TARGET_SYSROOT_ONLY"}, self.base / "new")

    def test_unresolved_advertised_dependency(self):
        pkg = Path(self.env["OPENCV_CROSS_PKG_CONFIG"])
        pkg.write_text(pkg.read_text().replace('--exists)', '--cflags) echo -lopencv_absent ;; --exists)'))
        self.reject("unresolved.*dependency flag")

    def test_missing_transitive_dependency(self):
        reader = Path(self.env["OPENCV_CROSS_READELF"])
        reader.write_text(reader.read_text().replace('-d)', '-d) echo "(NEEDED) [libabsent.so.1]";'))
        self.reject("unresolved target dependency")

    def test_broken_library_symlink(self):
        path = self.library / "libopencv_imgproc.so"
        path.unlink()
        path.symlink_to(self.library / "absent.so")
        self.reject("missing or invalid")

    def test_embedded_host_search(self):
        reader = Path(self.env["OPENCV_CROSS_READELF"])
        reader.write_text(reader.read_text().replace('-d)', '-d) echo "(RUNPATH) [/usr/lib/x86_64-linux-gnu]";'))
        self.reject("embedded target search")


@unittest.skipUnless(os.environ.get("OPENCV_REAL_SYSROOT_TEST") == "1",
                     "genuine SDK integration explicitly selected; no synthetic fallback")
class GenuineSysrootTests(unittest.TestCase):
    def test_partial_without_core(self):
        with patch.dict(os.environ, {}, clear=False):
            for name in ["OPENCV_CROSS_CORE_PREFIX", "OPENCV_CROSS_GPR_CONFIG",
                         "OPENCV_CROSS_GPRBUILD", "OPENCV_CROSS_GPRINSTALL"]:
                os.environ.pop(name, None)
            result = cross.validate(sysroot_only=True)
            self.assertFalse(result["production_qualified"])
            self.assertTrue(result["dependency_closure"])
            with self.assertRaisesRegex(cross.ConfigurationError, "OPENCV_CROSS_GPR_CONFIG"):
                cross.validate()

    def test_genuine_dependency_closure(self):
        result = cross.validate(sysroot_only=True)
        for module in ["core", "imgproc"]:
            self.assertIn(result["libraries"][module], result["dependency_closure"])


if __name__ == "__main__":
    unittest.main()