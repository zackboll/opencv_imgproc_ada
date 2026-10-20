"""Fresh public Debian reference qualification, NOT AdaCore/Yocto evidence.

Run in a disposable Debian 12 container with target compilers, GPR tools and
root package-download permissions. Core sources are read-only independent
inputs; this driver never edits them. WORK must be new and outside sources.
"""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import cross_configuration as cross
import cross_install_imgproc as installer
import qualify_static_runtime
import qualify_compatibility_archives


def main():
    cross.require(len(sys.argv) == 3, "usage: qualify_debian_reference.py CORE_SOURCE NEW_WORK")
    core, work = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    cross.require(not work.exists(), "reference work must not exist")
    work.mkdir(parents=True)
    target = "aarch64-linux-gnu"
    runtime = Path("/usr/lib/gcc-cross/aarch64-linux-gnu/12")
    sysroot = work / "sysroot"
    env = dict(os.environ, OPENCV_CROSS_TARGET=target, OPENCV_CROSS_ADA="/usr/bin/" + target + "-gcc",
               OPENCV_CROSS_CXX="/usr/bin/" + target + "-g++", OPENCV_CROSS_RUNTIME=str(runtime),
               ENV_PREFIX=str(sysroot), OPENCV_CROSS_PKG_CONFIG="/usr/bin/pkg-config",
               PKG_CONFIG_LIBDIR=str(sysroot / "usr/lib/aarch64-linux-gnu/pkgconfig"),
               OPENCV_IMGPROC_CROSS="True", OPENCV_CORE_CROSS="True")
    cross.logged(["sh", ROOT / "scripts/prepare_debian12_target.sh", sysroot, work / "packages"],
                 work / "sysroot-construction.log", env)
    # The target GNAT runtime shared object is an explicit deployment input.
    cross.logged(["sh", "-c", 'cd "$1" && apt-get download libgnat-12:arm64 && '
                  'for package in libgnat-12*.deb; do dpkg-deb -x "$package" "$2"; done',
                  "reference-runtime", str(work / "packages"), str(sysroot)], work / "gnat-runtime.log", env)
    os.environ.update(env)
    selected = installer.configuration(work, target, env["OPENCV_CROSS_ADA"], env["OPENCV_CROSS_CXX"], runtime, work / "unused-core", automatic=True)
    env["OPENCV_CROSS_GPR_CONFIG"] = str(selected)
    env["OPENCV_CROSS_GPRBUILD"] = installer.executable("OPENCV_CROSS_GPRBUILD", "gprbuild")
    env["OPENCV_CROSS_GPRINSTALL"] = installer.executable("OPENCV_CROSS_GPRINSTALL", "gprinstall")
    controls = dict(
        target=target, sysroot=str(sysroot), runtime=str(runtime), config=str(selected),
        ada=env["OPENCV_CROSS_ADA"], cxx=env["OPENCV_CROSS_CXX"],
        gprbuild=env["OPENCV_CROSS_GPRBUILD"], readelf="/usr/bin/readelf")
    qualify_static_runtime.qualify(controls, work / "static-runtime-control")
    qualify_static_runtime.qualify(controls, work / "tasking-runtime-control", tasking=True)
    qualify_compatibility_archives.qualify(controls, work / "compatibility-archive-control")
    cross.logged(["sh", core / "scripts/cross_build_core.sh", "--build", work / "core-build"],
                 work / "core-production.log", env)
    # Imgproc qualification must generate its own config, not reuse Core's.
    env.pop("OPENCV_CROSS_GPR_CONFIG")
    cross.logged(["sh", ROOT / "tests/cross/qualify_imgproc_cross_install.sh",
                  "--target", target, "--toolchain-bin", "/usr/bin", "--runtime", runtime,
                  "--sysroot", sysroot, "--core-prefix", work / "core-build/install",
                  "--prefix", work / "imgproc", "--profile", "release"], work / "imgproc-qualification.log", env)
    print(f"PASS Debian GNAT 12 reference; not vendor qualification. Evidence: {work}")


if __name__ == "__main__":
    try:
        main()
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(getattr(failure, "returncode", 1))