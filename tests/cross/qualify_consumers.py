"""Independent installed-only Ada and mixed Ada/C++ links, never execution."""
import json
import os
from pathlib import Path
import re
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import cross_configuration as cross
import cross_support as support


def qualify(settings, core, imgproc, work, logs, forbidden=()):
    cross.require(not work.exists() and not logs.exists(), "consumer directories must be fresh")
    work.mkdir(parents=True)
    logs.mkdir(parents=True)
    sources = cross.ROOT / "tests/installed_consumers"
    for source in sources.iterdir():
        if source.suffix in {".adb", ".ads", ".gpr", ".cpp"}:
            shutil.copyfile(source, work / source.name)
    libraries = [cross.resolved(prefix / "lib" / project, prefix) for prefix, projects in [
        (core, ["opencv_core", "opencv_core_shim"]), (imgproc, ["opencv_imgproc", "opencv_imgproc_shim"])] for project in projects]
    archives = [libraries[0] / "libopencv_core_ada.a", libraries[1] / "libopencv_core_shim.a",
                libraries[2] / "libopencv_imgproc_ada.a", libraries[3] / "libopencv_imgproc_shim.a"]
    for archive in archives:
        cross.elf(archive, settings["readelf"])
    for prefix in {core, imgproc}:
        support.check_alis(prefix, settings["ali_signature"])
    env = dict(os.environ, GPR_PROJECT_PATH=f"{core}/share/gpr:{imgproc}/share/gpr",
               OPENCV_CORE_LIBRARY_TYPE="static-pic", OPENCV_IMGPROC_LIBRARY_TYPE="static-pic")
    sysroot = "--sysroot=" + settings["sysroot"]
    summary = {}
    for kind in ["ada", "mixed"]:
        log = logs / (kind + "-build.log")
        cross.logged([settings["gprbuild"], "--config=" + settings["config"], "-P",
                      str(work / (kind + "_consumer.gpr")), "-p", "-v", "-R",
                      "-XCONSUMER_CXX=" + settings["cxx"], "-XCONSUMER_OPENCV_INCLUDE=-I" + settings["include"],
                      "-cargs:Ada", sysroot, *settings.get("ada_flags", []),
                      "-cargs:C++", sysroot, *settings.get("cxx_flags", []),
                      "-largs", sysroot, *settings.get("cxx_flags", []), "-Wl,-t",
                      *["-L" + str(directory) for directory in
                        support.loader_directories(Path(settings["sysroot"]), settings["target"])],
                      *["-Wl,-rpath-link," + str(directory) for directory in
                        support.loader_directories(Path(settings["sysroot"]), settings["target"])]], log, env, cwd=work)
        trace = log.read_text()
        tools = support.check_trace(log, dict(settings, core=str(core), work=str(work)), libraries)
        for archive in archives:
            cross.require(str(archive) in trace, f"consumer did not link {archive}")
        for prefix in [cross.ROOT, *([Path(settings["build_workspace"])] if settings.get("build_workspace") else []), *forbidden]:
            cross.require(str(prefix) + "/" not in trace, f"consumer resolved forbidden source/build/original prefix: {prefix}")
        executable = work / "bin" / ("installed_" + kind)
        result = support.executable_evidence(executable, settings)
        result["empty_compatibility_archives"] = {}
        result["link_inputs"] = support.link_inputs(
            log, settings, work, archives, result["empty_compatibility_archives"])
        for name in ["libopencv_core.so.", "libopencv_imgproc.so."]:
            cross.require(name in result["elf"], f"consumer missing native dependency {name}")
        support.check_alis(work, settings["ali_signature"])
        for path in work.rglob("*.o"):
            cross.elf(path, settings["readelf"])
        result.update(trace=tools, executable_sha256=cross.digest(executable), execution="NOT RUN")
        summary[kind] = result
    (logs / "consumers.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary