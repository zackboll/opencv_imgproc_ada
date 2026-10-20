"""Real AArch64 GNAT static-runtime link control, not vendor or execution evidence.

The -static binder choice is local to this control. It does not select a fully
static executable or alter production/runtime defaults. Text_IO ensures real
Ada runtime code is linked. A separate tasking control requires both archives.
"""
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import cross_configuration as cross
import cross_support as support


def qualify(settings, work, tasking=False):
    cross.require(work.is_absolute() and not work.exists(), "static-runtime control needs a new absolute workspace")
    work.mkdir(parents=True)
    print(f"Static-runtime control evidence retained: {work}", flush=True)
    for suffix in ["adb", "gpr"]:
        name = "static_runtime_probe." + suffix
        shutil.copyfile(ROOT / "tests/fixtures/cross-reference" / name, work / name)
    if tasking:
        shutil.copyfile(ROOT / "tests/fixtures/cross-reference/tasking_runtime_probe.adb",
                        work / "static_runtime_probe.adb")
    sysroot = "--sysroot=" + settings["sysroot"]
    directories = support.loader_directories(Path(settings["sysroot"]), settings["target"])
    log = work / "static-runtime-link.log"
    command = [settings["gprbuild"], "--config=" + settings["config"], "-P",
               str(work / "static_runtime_probe.gpr"), "-p", "-v", "-R",
               "-cargs:Ada", sysroot, "-bargs:Ada", "-static",
               "-largs", sysroot, "-Wl,-t",
               *["-L" + str(directory) for directory in directories],
               *["-Wl,-rpath-link," + str(directory) for directory in directories]]
    cross.logged(command, log, dict(os.environ), cwd=work)
    empty_archives = {}
    inputs = support.link_inputs(log, settings, work, empty_archives=empty_archives)
    selected = [cross.resolved(Path(settings["runtime"]) / "adalib" / name)
                for name in (["libgnat.a", "libgnarl.a"] if tasking else ["libgnat.a"])]
    for archive in selected:
        cross.require(str(archive) in inputs, f"static runtime archive absent from real trace: {archive}")
    cross.require(not any(Path(path).name.startswith(("libgnat", "libgnarl"))
                          and ".so" in Path(path).name for path in inputs),
                  "static-runtime control linked a shared Ada runtime")
    executable = work / "bin/static_runtime_probe"
    evidence = support.executable_evidence(executable, settings)
    evidence.update(command=command, compiler=cross.run([settings["ada"], "--version"]),
                    runtime=settings["runtime"], link_inputs=inputs,
                    empty_compatibility_archives=empty_archives, tasking=tasking,
                    selected_archives={str(path): cross.digest(path) for path in selected},
                    executable_sha256=cross.digest(executable), execution="NOT RUN")
    (work / "static-runtime-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("PASS real GNAT static Ada runtime link control (not execution or vendor qualification)", flush=True)
    return evidence


if __name__ == "__main__":
    try:
        cross.require(len(sys.argv) == 3, "usage: qualify_static_runtime.py INSTALLATION_JSON NEW_WORK")
        settings = json.loads(Path(sys.argv[1]).read_text())
        os.environ["OPENCV_CROSS_TARGET"] = settings["target"]
        qualify(settings, Path(sys.argv[2]))
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(getattr(failure, "returncode", 1))