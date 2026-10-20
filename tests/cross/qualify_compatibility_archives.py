"""Genuine Debian AArch64 link and metadata control, not vendor/execution evidence.

Only use a disposable test sysroot: temporary pkg-config metadata is added in a
new directory and removed on exit. No archive or existing metadata is changed.
"""
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import cross_configuration as cross
import cross_support as support


def qualify(settings, work):
    cross.require(work.is_absolute() and not work.exists(), "compatibility control needs a new absolute workspace")
    work.mkdir(parents=True)
    sysroot = Path(settings["sysroot"])
    directories = support.loader_directories(sysroot, settings["target"])
    archives = {}
    for name in sorted(support.GLIBC_COMPATIBILITY_ARCHIVES):
        candidates = {cross.resolved(directory / name, sysroot) for directory in directories
                      if (directory / name).is_file()}
        for path in sorted(candidates):
            empty = support.empty_compatibility_archive(path, sysroot)
            if empty:
                archives[str(path)] = empty
    cross.require(archives, "Debian compatibility control found no genuine empty glibc archives")
    original_pc = cross.resolved(next(sysroot.rglob("opencv4.pc")), sysroot)
    # Exercise real pkg-config and the complete preflight, not only recognition.
    with tempfile.TemporaryDirectory(prefix="compatibility-control-", dir=original_pc.parent) as directory:
        metadata = Path(directory) / "opencv4.pc"
        lines = original_pc.read_text().splitlines()
        metadata.write_text("\n".join(line + " " + " ".join(archives) if line.startswith("Libs:")
                                      else line for line in lines) + "\n")
        with patch.dict(os.environ, PKG_CONFIG_LIBDIR=directory + os.pathsep + os.environ["PKG_CONFIG_LIBDIR"]):
            preflight = cross.validate(sysroot_only=True)
        cross.require(preflight["empty_compatibility_archives"] == archives, "metadata stub evidence differs")
        cross.require(not set(archives).intersection(preflight["dependency_closure"]), "stub entered ELF roots")
        (work / "preflight.json").write_text(json.dumps(preflight, indent=2) + "\n")
        (work / "opencv4-control.pc").write_bytes(metadata.read_bytes())
    source = work / "compatibility_probe.cpp"
    source.write_text("int main() { return 0; }\n")
    obj, executable = work / "compatibility_probe.o", work / "compatibility_probe"
    sysroot_switch = "--sysroot=" + str(sysroot)
    cross.logged([settings["cxx"], sysroot_switch, "-c", str(source), "-o", str(obj)],
                 work / "compile.log", dict(os.environ))
    log = work / "link.log"
    command = [settings["cxx"], sysroot_switch, str(obj), "-o", str(executable), "-Wl,-t",
               *["-L" + str(directory) for directory in directories], *archives,
               *["-Wl,-rpath-link," + str(directory) for directory in directories]]
    cross.logged(command, log, dict(os.environ))
    actual = {}
    inputs = support.link_inputs(log, settings, work, empty_archives=actual)
    cross.require(actual == archives, "genuine compatibility archives missing from actual linker trace")
    for path, evidence in archives.items():
        cross.require(inputs.get(path) == evidence["sha256"] == cross.digest(path), "trace/hash mismatch")
    evidence = support.executable_evidence(executable, settings)
    evidence.update(command=command, compiler=cross.run([settings["cxx"], "--version"]),
                    link_inputs=inputs, empty_compatibility_archives=actual, execution="NOT RUN")
    (work / "compatibility-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS genuine Debian compatibility archive metadata/link control: {work}", flush=True)
    return evidence