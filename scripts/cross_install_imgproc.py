"""Build/install Imgproc against installed target Core, without Alire.

Required roots are independent. OPENCV_CROSS_ADA, CXX, GPRBUILD, GPRINSTALL,
GPRCONFIG, PKG_CONFIG, READELF and GPR_CONFIG (all with OPENCV_CROSS_ prefix)
override tool discovery. CPU flags use OPENCV_CROSS_ADA_FLAGS/CXX_FLAGS JSON
arrays. Failed workspaces are retained; external prefixes are never deleted.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from xml.sax.saxutils import escape

import cross_configuration as cross
import cross_support as support


def executable(variable, default):
    selected = shutil.which(os.environ.get(variable) or default)
    cross.require(selected, f"{variable} executable unavailable: {default}")
    path = str(Path(selected).absolute())
    os.environ[variable] = path
    return path


def prefix_safety(prefix, source, sysroot, core, work=None):
    cross.require(prefix.is_absolute() and not cross.re.search(r'[\s"\\]', str(prefix)),
                  "installation prefix must be an absolute path without whitespace/quotes")
    cross.require(not any(path.is_symlink() for path in [prefix, *prefix.parents]),
                  "installation prefix is a symlink")
    prefix = prefix.resolve()
    cross.require(prefix != Path("/"), "dedicated installation prefix required")
    for protected in [source, sysroot, *([work] if work else [])]:
        cross.require(not cross.inside(prefix, protected) and not cross.inside(protected, prefix),
                      f"installation prefix overlaps {protected}")
    cross.require(prefix == core or (not cross.inside(prefix, core) and not cross.inside(core, prefix)),
                  "Core and Imgproc prefixes must be separate or identical, not nested")
    for name in ["share/gpr/opencv_imgproc.gpr", "share/gpr/opencv_imgproc_shim.gpr",
                 "lib/opencv_imgproc", "lib/opencv_imgproc_shim", "share/doc/opencv_imgproc"]:
        cross.require(not (prefix / name).exists() and not (prefix / name).is_symlink(),
                      f"refusing to replace existing Imgproc content: {prefix / name}")
    return prefix


def inventory(root):
    """A byte-level before/after record, including existing metadata/symlinks."""
    return {str(path.relative_to(root)): ("symlink:" + os.readlink(path) if path.is_symlink()
            else cross.digest(path)) for path in root.rglob("*") if path.is_file() or path.is_symlink()}


def preserve(before, root):
    after = inventory(root)
    cross.require(all(after.get(name) == digest for name, digest in before.items()),
                  "existing Core/prefix content changed")


def publish(staged, prefix):
    """Preflight every file, then exclusively create; never overwrite Core."""
    entries = sorted(staged.rglob("*"))
    for source in entries:
        destination = prefix / source.relative_to(staged)
        cross.require(not source.is_symlink(), f"staged symlink: {source}")
        cross.require(not any(path.is_symlink() for path in [destination, *destination.parents]),
                      f"installation symlink: {destination}")
        cross.require(not destination.exists() or (source.is_dir() and destination.is_dir()),
                      f"installation conflict; no files published: {destination}")
    for source in entries:
        destination = prefix / source.relative_to(staged)
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("xb") as output, source.open("rb") as input_file:
                shutil.copyfileobj(input_file, output)
            shutil.copymode(source, destination)


def configuration(work, target, ada, cxx, runtime, core, automatic=False):
    override = os.environ.get("OPENCV_CROSS_GPR_CONFIG")
    cross.require(not automatic or not override, "qualification requires automatic CGPR; unset OPENCV_CROSS_GPR_CONFIG")
    if override:
        selected = cross.resolved(override)
        support.check_configuration(selected, target, ada, cxx, runtime)
        (work / "gprconfig.log").write_text(f"Explicit configuration: {selected}\n")
        return selected
    if not automatic:
        for candidate in [core / f"share/gprconfig/opencv_core-{target}.cgpr",
                          core / f"share/gprconfig/{target}.cgpr"]:
            if candidate.is_file():
                try:
                    support.check_configuration(candidate, target, ada, cxx, runtime)
                except cross.ConfigurationError:
                    continue
                cross.resolved(candidate, core)
                (work / "gprconfig.log").write_text(f"Reused validated configuration: {candidate}\n")
                return candidate
    selected = work / "target.cgpr"
    gprconfig = executable("OPENCV_CROSS_GPRCONFIG", "gprconfig")
    # Older knowledge bases recognize only unprefixed g++. Add discovery for
    # precisely the actual driver, retaining G++'s standard configuration rules.
    # This is input to GPRconfig, not an edit of its generated configuration.
    database = work / "gprconfig-db"
    database.mkdir()
    (database / "selected-cxx.xml").write_text(
        '<?xml version="1.0"?><gprconfig><compiler_description><name>G++</name>'
        '<executable>' + escape(cross.re.escape(Path(cxx).name)) + '</executable>'
        '<version><external>$EXEC -dumpfullversion</external><grep regexp="[^\\r\\n]+"/></version>'
        '<languages>C++</languages><target><external>$EXEC -dumpmachine</external>'
        '<grep regexp="[^\\r\\n]+"/></target></compiler_description></gprconfig>\n')
    cross.logged([gprconfig, "--db", database, "--batch", "--target=" + target,
                  f"--config=Ada,,{runtime},{Path(ada).parent},GNAT",
                  f"--config=C++,,,{Path(cxx).parent},{Path(cxx).name}", "-o", selected],
                 work / "gprconfig.log", dict(os.environ))
    support.check_configuration(selected, target, ada, cxx, runtime)
    return selected


def installed_closure(staged, settings):
    projects = staged / "share/gpr"
    for name in ["opencv_imgproc", "opencv_imgproc_shim"]:
        cross.require((projects / (name + ".gpr")).is_file(), f"missing installed {name} project")
    for project in projects.glob("*.gpr"):
        text = cross.re.sub(r"--[^\n]*", "", project.read_text())
        for imported in cross.re.findall(r'\bwith\s+"([^"\n]+)"', text, cross.re.I):
            cross.require("/" not in imported, f"nonrelocatable project import: {project}: {imported}")
            name = imported if imported.endswith(".gpr") else imported + ".gpr"
            cross.require((projects / name).is_file() or (Path(settings["core"]) / "share/gpr" / name).is_file(),
                          f"missing installed import: {name}")
        for candidate in cross.re.findall(r'"([^"\n]+)"', text):
            if candidate.startswith(("-I/", "-L/")):
                candidate = candidate[2:]
            if candidate.startswith("/"):
                cross.require(candidate in {settings["ada"], settings["cxx"], settings["runtime"], settings["runtime"] + "/"}
                              or cross.inside(Path(candidate).resolve(), Path(settings["sysroot"])),
                              f"build/source prefix in installed project: {candidate}")
    for library, archive in [("opencv_imgproc", "opencv_imgproc_ada"), ("opencv_imgproc_shim", "opencv_imgproc_shim")]:
        cross.elf(staged / f"lib/{library}/lib{archive}.a", settings["readelf"])
    support.check_alis(staged, settings["ali_signature"])


def consumers():
    spec = importlib.util.spec_from_file_location("imgproc_consumers", cross.ROOT / "tests/cross/qualify_consumers.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def qualify(settings, core, prefix, evidence):
    consumer = consumers()
    consumer.qualify(settings, core, prefix, evidence / "installed-work", evidence / "installed-logs")
    relocated = evidence / "relocated/a-longer-installation-root"
    copied_core = relocated / "core"
    shutil.copytree(core, copied_core, symlinks=True)
    copied_imgproc = copied_core if core == prefix else relocated / "imgproc"
    if copied_imgproc != copied_core:
        shutil.copytree(prefix, copied_imgproc, symlinks=True)
    copied = dict(settings, core=str(copied_core), config=str(copied_imgproc / "share/gprconfig" / Path(settings["config"]).name))
    consumer.qualify(copied, copied_core, copied_imgproc, evidence / "relocated-work",
                     evidence / "relocated-logs", forbidden=[core, prefix])
    (evidence / "dispositions.txt").write_text(
        "PASS full production build/install; workspace removed; installed and relocated Ada/mixed links\n"
        "TARGET_RUNTIME_PENDING: no target execution performed\n")


def install(arguments):
    parser = argparse.ArgumentParser(description=__doc__)
    for option, variable in [("target", "OPENCV_CROSS_TARGET"), ("runtime", "OPENCV_CROSS_RUNTIME"),
                             ("sysroot", "ENV_PREFIX"), ("core-prefix", "OPENCV_CROSS_CORE_PREFIX"),
                             ("prefix", "OPENCV_CROSS_INSTALL_PREFIX")]:
        parser.add_argument("--" + option, default=os.environ.get(variable), required=not os.environ.get(variable))
    parser.add_argument("--toolchain-bin", required=True)
    parser.add_argument("--source-root", default=os.environ.get("OPENCV_CROSS_SOURCE_ROOT"),
                        help="explicit clean Git root or Git-free release source directory")
    parser.add_argument("--profile", choices=["release", "development", "validation"], default="release")
    parser.add_argument("--qualify", action="store_true", help="force automatic CGPR and fresh prefix; repeat relocated consumers")
    options = parser.parse_args(arguments)
    source = cross.resolved(options.source_root or cross.ROOT)
    if options.source_root:
        os.environ["OPENCV_CROSS_SOURCE_ROOT"] = str(source)
    cross.ROOT = source
    cross.run(["sh", str(source / "scripts/validate_cross_target.sh"), options.target])
    toolchain, runtime, sysroot, core = map(cross.resolved, [options.toolchain_bin, options.runtime, options.sysroot, options.core_prefix])
    prefix = prefix_safety(Path(options.prefix), source, sysroot, core)
    cross.require(not options.qualify or not prefix.exists(), "qualification requires a fresh nonexistent Imgproc prefix")
    for protected in [source, sysroot]:
        cross.require(not cross.inside(core, protected) and not cross.inside(protected, core), "Core overlaps source/sysroot")
    os.environ.update(OPENCV_CROSS_TARGET=options.target, OPENCV_CROSS_RUNTIME=str(runtime),
                      ENV_PREFIX=str(sysroot), OPENCV_CROSS_CORE_PREFIX=str(core), OPENCV_CROSS_PROFILE=options.profile)
    os.environ["PATH"] = str(toolchain) + os.pathsep + os.environ["PATH"]
    ada = executable("OPENCV_CROSS_ADA", str(toolchain / (options.target + "-gcc")))
    cxx = executable("OPENCV_CROSS_CXX", str(toolchain / (options.target + "-g++")))
    for name, default in [("GPRBUILD", "gprbuild"), ("GPRINSTALL", "gprinstall"), ("PKG_CONFIG", "pkg-config")]:
        executable("OPENCV_CROSS_" + name, default)
    if not os.environ.get("PKG_CONFIG_LIBDIR"):
        os.environ["PKG_CONFIG_LIBDIR"] = ":".join(str(path) for path in [
            sysroot / "usr/lib/pkgconfig", sysroot / f"usr/lib/{options.target}/pkgconfig",
            sysroot / "usr/lib64/pkgconfig", sysroot / "usr/share/pkgconfig", sysroot / "lib/pkgconfig"] if path.is_dir())
    work = Path(tempfile.mkdtemp(prefix="opencv-imgproc-cross-")).resolve()
    evidence = Path(tempfile.mkdtemp(prefix="opencv-imgproc-evidence-")).resolve()
    print(f"Production workspace: {work}\nEvidence retained: {evidence}", flush=True)
    try:
        prefix_safety(prefix, source, sysroot, core, work)
        before = inventory(core)
        selected = configuration(work, options.target, ada, cxx, runtime, core, options.qualify)
        os.environ["OPENCV_CROSS_GPR_CONFIG"] = str(selected)
        settings = cross.validate(independent_toolchains=True)
        settings.update(tool_versions={name: cross.run([settings[name], "--version"]) for name in ["ada", "cxx", "gprbuild", "gprinstall"]},
                        core_inventory=before)
        cross.workspace("--build", str(work / "build"), settings)
        staged = work / "build/install"
        installed_closure(staged, settings)
        relative = Path(f"share/gprconfig/opencv_imgproc-{options.target}.cgpr")
        (staged / relative).parent.mkdir(parents=True)
        shutil.copyfile(selected, staged / relative)
        settings["config"] = str(prefix / relative)
        settings["build_workspace"] = str(work)
        settings["source_identity"] = (work / "build/source-revision.txt").read_text().strip()
        for directory in [work, work / "build"]:
            for path in directory.iterdir():
                if path.is_file() and path.suffix in {".log", ".json", ".txt", ".cgpr"}:
                    shutil.copyfile(path, evidence / path.name)
        (evidence / "installation.json").write_text(json.dumps(settings, indent=2) + "\n")
        # Qualify the staged closure before any external file is published.
        staged_settings = dict(settings, config=str(staged / relative))
        staged_settings.pop("build_workspace")
        consumers().qualify(staged_settings, core, staged, evidence / "staged-work", evidence / "staged-logs")
        preserve(before, core)
        publish(staged, prefix)
        preserve(before, core)
        shutil.rmtree(work)  # Only this task-owned workspace, after successful publication.
        cross.require(not work.exists(), "production workspace cleanup failed")
        if options.qualify:
            qualify(settings, core, prefix, evidence)
        else:
            consumers().qualify(settings, core, prefix, evidence / "installed-work", evidence / "installed-logs")
        preserve(before, core)
    except BaseException:
        (evidence / "dispositions.txt").write_text(f"FAIL; workspace (if present): {work}\n")
        print(f"Cross-install FAIL; retained diagnostics: {work} and {evidence}", file=sys.stderr)
        raise
    print(f"PASS Imgproc production build/install and independent consumers\nPrefix: {prefix}\n"
          f"Durable configuration: {prefix / relative}\nEvidence: {evidence}\nTARGET_RUNTIME_PENDING", flush=True)


if __name__ == "__main__":
    try:
        install(sys.argv[1:])
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(getattr(failure, "returncode", 1))