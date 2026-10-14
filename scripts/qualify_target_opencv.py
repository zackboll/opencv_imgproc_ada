"""Real compile/link evidence, never Ada production or target execution evidence."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import cross_configuration as cross


def qualify(destination):
    settings = cross.validate(sysroot_only=True)
    output = Path(destination)
    cross.require(output.is_absolute() and not output.exists(), "new absolute evidence directory required")
    output.mkdir(parents=True)
    (output / "sysroot.json").write_text(json.dumps(settings, indent=2) + "\n")
    compiler = settings["cxx"]
    switches = ["--sysroot=" + settings["sysroot"]]
    library = Path(settings["library"])
    source = cross.ROOT / "tests/fixtures/cross-reference/opencv_link_probe.cpp"
    object_file = output / "opencv-probe.o"
    compile_command = [compiler, *switches, "-std=c++17", "-Wall", "-Wextra", "-Werror", "-v",
                       *settings["cflags"], "-c", str(source), "-o", str(object_file)]
    compilation = subprocess.run(compile_command, text=True, capture_output=True)
    (output / "compiler-trace.txt").write_text(compilation.stdout + compilation.stderr)
    cross.require(compilation.returncode == 0, compilation.stderr)
    search = compilation.stderr.split('#include <...> search starts here:')[-1].split('End of search list.')[0]
    cross.require("x86_64-linux-gnu" not in search, "host development include contamination")
    # Explicit target development search precedes Debian GCC's external runtime.
    link_search = ["-B" + str(library) + "/", "-L" + str(library),
                   "-L" + str(Path(settings["sysroot"]) / "lib/aarch64-linux-gnu")]
    dependency_dirs = sorted({str(Path(path).parent) for path in settings["dependency_closure"]})
    command = [compiler, *switches, "-std=c++17", "-Wall", "-Wextra", "-Werror",
               *link_search, str(object_file),
               settings["libraries"]["imgproc"], settings["libraries"]["core"],
               str(cross.resolved(next(Path(settings["sysroot"]).rglob("libstdc++.so.6")))),
               "-Wl,-t", "-Wl,-rpath-link," + ":".join(dependency_dirs),
               "-o", str(output / "opencv-probe")]
    (output / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    trace = cross.run(command)
    (output / "link-trace.txt").write_text(trace + "\n")
    sysroot = Path(settings["sysroot"])
    # GCC-owned target startup/runtime files may live outside the sysroot.
    # Accept only exact compiler-reported files, never arbitrary native paths.
    runtime = set()
    for name in ["crtbeginS.o", "crtendS.o", "libstdc++.so", "libgcc_s.so", "libgcc.a"]:
        path = cross.resolved(cross.run([compiler, *switches, *link_search, "-print-file-name=" + name]))
        runtime.add(path)
        if path.suffix != ".so" or path.read_bytes()[:4] == b"\x7fELF":
            cross.elf(path, settings["readelf"])
    resolved_inputs = []
    for line in trace.splitlines():
        if line.startswith("/"):
            path = cross.resolved(line)
            cross.require(cross.inside(path, sysroot) or path in runtime or path == object_file,
                          f"unqualified linker input outside sysroot: {path}")
            if path.read_bytes()[:4] == b"\x7fELF" or path.suffix == ".a":
                cross.elf(path, settings["readelf"])
            resolved_inputs.append(str(path))
    (output / "resolved-inputs.json").write_text(json.dumps(resolved_inputs, indent=2) + "\n")
    executable = output / "opencv-probe"
    (output / "elf.txt").write_text(cross.elf(executable, settings["readelf"]))
    dynamic = cross.run([settings["readelf"], "-d", str(executable)])
    cross.require(all(re.search(r'\(NEEDED\).*\[libopencv_' + module + r'\.so\.', dynamic)
                      for module in ["core", "imgproc"]), "probe missing Core/Imgproc linkage")
    (output / "dynamic.txt").write_text(dynamic + "\n")
    closure = cross.dependency_closure([executable], sysroot, settings["readelf"], generated=executable)
    (output / "probe-closure.json").write_text(json.dumps(closure, indent=2) + "\n")
    print("TARGET_SYSROOT_QUALIFIED\nTARGET_PKGCONFIG_QUALIFIED\nTARGET_OPENCV_LINK_QUALIFIED")
    bridge = os.environ.get("OPENCV_CROSS_CORE_BRIDGE")
    if bridge:
        header = cross.resolved(Path(bridge) / "opencv_core_module_bridge.hpp")
        # Compile-only may use the exact dependency source header, not an install claim.
        (output / "bridge.json").write_text(json.dumps(dict(path=str(header), sha256=cross.digest(header))))
        cross.run([compiler, *switches, "-std=c++17", "-Wall", "-Wextra", "-Werror", "-fPIC",
                   *settings["cflags"], "-I" + str(header.parent), "-c",
                   str(cross.ROOT / "cpp/opencv_imgproc_shim.cpp"), "-o", str(output / "imgproc-shim.o")])
        (output / "shim-elf.txt").write_text(cross.elf(output / "imgproc-shim.o", settings["readelf"]))
        print("IMGPROC_CXX_OBJECT_QUALIFIED (compile-only, source bridge)")
    print("PRODUCTION_CROSS_BUILD_PENDING; target execution NOT RUN")


if __name__ == "__main__":
    try:
        cross.require(len(sys.argv) == 2, "usage: qualify_target_opencv.py NEW_ABSOLUTE_EVIDENCE")
        qualify(sys.argv[1])
    except (cross.ConfigurationError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)