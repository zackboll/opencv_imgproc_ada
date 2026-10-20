"""Target-only configuration. Standard-library tooling, not an SDK installer.

Inputs must remain stable during validation/build; this is not a hostile-file
mutation sandbox. Synthetic tests of this module are not compiler evidence.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import cross_support as support


ROOT = Path(__file__).resolve().parents[1]


class ConfigurationError(Exception):
    """A failed cross prerequisite; never select a host substitute."""

    def __init__(self, message, returncode=1):
        super().__init__(message)
        self.returncode = returncode


def require(condition, message):
    if not condition:
        raise ConfigurationError(message)


def run(args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    if result.returncode:
        raise ConfigurationError(f"command failed: {args}\n{result.stdout}{result.stderr}", result.returncode)
    return result.stdout.strip()


def value(name):
    text = os.environ.get(name, "")
    require(text, f"{name} is required")
    require(not re.search(r'[\s"\\]', text), f"unsafe input: {name}")
    return text


def tool(name, default=None):
    selected = os.environ.get(name, default) if default else value(name)
    path = shutil.which(selected or "")
    require(path, f"{name} executable unavailable: {selected}")
    return str(Path(path).absolute())


def inside(path, parent):
    return path == parent or parent in path.parents


def resolved(path, parent=None):
    try:
        result = Path(path).resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise ConfigurationError(f"missing or invalid target path: {path}: {error}") from error
    require(parent is None or inside(result, parent), f"path escapes sysroot: {path}")
    return result


def tree(path, parent):
    # GNU find -L diagnoses cycles; inspect every entry, including nested links.
    output = subprocess.run(["find", "-L", str(path), "-print0"], capture_output=True)
    require(output.returncode == 0, f"invalid target tree: {path}")
    for entry in output.stdout.split(b"\0"):
        if entry:
            resolved(os.fsdecode(entry), parent)


def elf(path, readelf):
    details = run([readelf, "-h", str(path)])
    for field, expected in [("Machine", "AArch64"), ("Class", "ELF64"),
                            ("Data", "2's complement, little endian")]:
        entries = re.findall(rf"^\s*{field}:\s*(.+)$", details, re.MULTILINE)
        require(entries and all(item.strip() == expected for item in entries),
                f"not ELF64 little-endian AArch64 (or mixed archive): {path}: {field}")
    return details


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dependency_closure(paths, sysroot, readelf, generated=None):
    """Resolve every DT_NEEDED to a contained, architecture-checked target ELF."""
    directories = support.loader_directories(sysroot, value("OPENCV_CROSS_TARGET"))
    visited = {}
    pending = list(paths)
    while pending:
        entry = pending.pop()
        path = resolved(entry, None if generated and Path(entry) == generated else sysroot)
        if str(path) in visited:
            continue
        elf(path, readelf)
        dynamic = run([readelf, "-d", str(path)])
        for search_path in re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]+)\]', dynamic):
            for directory in search_path.split(":"):
                require(directory.startswith("/") and "x86_64" not in directory,
                        f"unqualified embedded target search path: {path}: {directory}")
                # Runtime absolute paths refer to the target root, not the build host.
                resolved(sysroot / directory.lstrip("/"), sysroot)
        needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', dynamic)
        resolution = {}
        visited[str(path)] = dict(sha256=digest(path), needed=resolution)
        for name in needed:
            require('/' not in name, f"unsafe target dependency: {name}")
            candidate = next((directory / name for directory in directories
                              if (directory / name).exists() or (directory / name).is_symlink()), None)
            require(candidate, f"unresolved target dependency: {name} from {path}")
            dependency = resolved(candidate, sysroot)
            resolution[name] = str(dependency)
            pending.append(dependency)
    return visited


def validate(sysroot_only=False, independent_toolchains=False):
    target = value("OPENCV_CROSS_TARGET")
    run(["sh", str(ROOT / "scripts/validate_cross_target.sh"), target])
    sysroot = resolved(value("ENV_PREFIX"))
    require(sysroot.is_dir() and sysroot != Path("/"), "dedicated target sysroot required")
    for name in ["CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "LIBRARY_PATH",
                 "GCC_EXEC_PREFIX", "COMPILER_PATH", "ADA_INCLUDE_PATH",
                 "ADA_OBJECTS_PATH", "GPR_PROJECT_PATH", "ADA_PROJECT_PATH",
                 "LD_LIBRARY_PATH", "ADA_PRJ_INCLUDE_FILE", "ADA_PRJ_OBJECTS_FILE"]:
        require(not os.environ.get(name), f"cross mode requires empty {name}")
    ada, cxx = tool("OPENCV_CROSS_ADA"), tool("OPENCV_CROSS_CXX")
    for compiler in [ada, cxx]:
        require(run([compiler, "-dumpmachine"]) == target, f"compiler target mismatch: {compiler}")
    readelf = tool("OPENCV_CROSS_READELF", "readelf")
    runtime = resolved(value("OPENCV_CROSS_RUNTIME"))
    require((runtime / "adainclude").is_dir() and (runtime / "adalib").is_dir(),
            "target Ada runtime must contain adainclude and adalib")
    runtime_evidence = support.runtime_identity(ada, runtime)
    elf(resolved(runtime / "adalib/libgnat.a"), readelf)
    pkg = tool("OPENCV_CROSS_PKG_CONFIG")
    libdirs = value("PKG_CONFIG_LIBDIR").split(":")
    require(all(libdirs), "empty pkg-config search component")
    for directory in libdirs:
        metadata = resolved(directory, sysroot)
        require(metadata.is_dir(), "missing target pkg-config directory")
        tree(metadata, sysroot)
    require(not os.environ.get("PKG_CONFIG_PATH"), "PKG_CONFIG_PATH must be empty")
    require(os.environ.get("PKG_CONFIG_SYSROOT_DIR", str(sysroot)) == str(sysroot),
            "pkg-config sysroot mismatch")
    env = dict(os.environ, PKG_CONFIG_SYSROOT_DIR=str(sysroot))
    package = None
    for candidate in ["opencv5", "opencv4", "opencv"]:
        if subprocess.run([pkg, "--exists", candidate], env=env, capture_output=True).returncode == 0:
            package = candidate
            break
    require(package, "target OpenCV pkg-config metadata missing")
    version = run([pkg, "--modversion", package], env=env)
    require(re.fullmatch(r"(?:4\.(?:[1-9][0-9]*)|5\.0)(?:\.[0-9]+)*", version),
            f"unsupported OpenCV version: {version}")

    def metadata_path(name):
        raw = run([pkg, f"--variable={name}", package], env=env)
        require(raw.startswith("/"), "OpenCV metadata path must be absolute")
        path = Path(raw)
        if not inside(path, sysroot):
            path = sysroot / raw.lstrip("/")
        return resolved(path, sysroot)

    include, library = metadata_path("includedir"), metadata_path("libdir")
    tree(include, sysroot)
    for header in ["core.hpp", "imgproc.hpp", "core/version.hpp"]:
        require((include / "opencv2" / header).is_file(), f"missing target header: {header}")
    header_version = (include / "opencv2/core/version.hpp").read_text()
    numbers = [re.search(rf"#\s*define\s+CV_VERSION_{part}\s+(\d+)", header_version)
               for part in ["MAJOR", "MINOR", "REVISION"]]
    require(all(numbers) and ".".join(match[1] for match in numbers) == version,
            "OpenCV header/pkg-config version mismatch")
    flags = run([pkg, "--cflags", "--libs", package], env=env).split()
    advertised = []
    search = [library]
    for flag in flags:
        if flag.startswith("-L"):
            search.append(resolved(flag[2:], sysroot))
    for flag in flags:
        if flag.startswith(("-I", "-L")):
            directory = resolved(flag[2:], sysroot)
            require(directory.is_dir(), "missing pkg-config dependency directory")
            if flag.startswith("-I"):
                tree(directory, sysroot)
        elif flag.startswith("/"):
            path = resolved(flag, sysroot)
            elf(path, readelf)
            advertised.append(path)
        else:
            require(re.fullmatch(r"-l(?:opencv_[a-z0-9_]+|stdc\+\+)|-D[A-Za-z0-9_=]+|-pthread", flag),
                    f"unsupported target pkg-config flag: {flag}")
            if flag.startswith("-l"):
                name = "lib" + flag[2:] + ".so"
                matches = {resolved(directory / name, sysroot) for directory in search
                           if (directory / name).exists()}
                require(len(matches) == 1, f"unresolved or ambiguous target dependency flag: {flag}")
                advertised.extend(matches)
    cflags = run([pkg, "--cflags", package], env=env).split()
    require(all(flag.startswith(("-I", "-D")) or flag == "-pthread" for flag in cflags),
            "invalid target cflags")
    libraries = {}
    for module in ["core", "imgproc"]:
        path = library / f"libopencv_{module}.so"
        if not path.is_file():
            path = library / f"libopencv_{module}.a"
        libraries[module] = str(resolved(path, sysroot))
        elf(libraries[module], readelf)
        # Shared OpenCV modules must advertise matching ABI versions.
        if ".so" in libraries[module]:
            dynamic = run([readelf, "-d", libraries[module]])
            abi = version.split(".")
            sonames = re.findall(r'\(SONAME\).*\[([^\]]+)\]', dynamic)
            expected_soname = f"libopencv_{module}.so.{abi[0]}{int(abi[1]):02d}"
            require(expected_soname in sonames,
                    f"OpenCV {module} SONAME/version mismatch")
    for name in ["libc.so.6", "libstdc++.so.6"]:
        found = list(sysroot.rglob(name))
        require(found, f"missing target runtime library: {name}")
        for path in found:
            elf(resolved(path, sysroot), readelf)

    closure = dependency_closure(advertised + list(libraries.values()), sysroot, readelf)
    support.check_versions(closure, readelf)
    qualified = dict(target=target, sysroot=str(sysroot), ada=ada, cxx=cxx,
                     runtime=str(runtime), readelf=readelf, include=str(include),
                     library=str(library), libraries=libraries, version=version,
                     cflags=cflags, pkgconfig_flags=flags, dependency_closure=closure,
                     qualification="TARGET_SYSROOT_ONLY", production_qualified=False)
    if sysroot_only:
        require(all("-lopencv_" + module in flags for module in ["core", "imgproc"]),
                "target pkg-config metadata lacks required Core/Imgproc link flags")
        pcdir = resolved(run([pkg, "--variable=pcfiledir", package], env=env), sysroot)
        metadata_file = resolved(pcdir / (package + ".pc"), sysroot)
        qualified["pkgconfig_metadata"] = dict(path=str(metadata_file), sha256=digest(metadata_file))
        for name in ["libgcc.a", "libstdc++.so"]:
            compiler_runtime = resolved(run([cxx, "--sysroot=" + str(sysroot), "-print-file-name=" + name]))
            elf(compiler_runtime, readelf)
            if name == "libstdc++.so":
                target_runtime = resolved(next(sysroot.rglob("libstdc++.so.6")), sysroot)
                compiler_symbols = set(re.findall(r'(?:GLIBCXX|CXXABI)_[0-9.]+',
                    run([readelf, "--version-info", str(compiler_runtime)])))
                target_symbols = set(re.findall(r'(?:GLIBCXX|CXXABI)_[0-9.]+',
                    run([readelf, "--version-info", str(target_runtime)])))
                require(compiler_symbols and compiler_symbols <= target_symbols,
                        "compiler/sysroot libstdc++ runtime mismatch")
                qualified["cxx_runtime_symbols"] = sorted(target_symbols)
        qualified["compiler_version"] = run([cxx, "-dumpfullversion"])
        qualified["ada_version"] = run([ada, "-dumpfullversion"])
        if not independent_toolchains:
            require(qualified["compiler_version"] == qualified["ada_version"],
                    "GCC/GNAT compiler runtime version mismatch")
        # Different versions are not ABI evidence: actual link and runtime
        # symbol-version checks remain independent gates.
        qualified["independent_toolchains"] = independent_toolchains
        return qualified

    config = resolved(value("OPENCV_CROSS_GPR_CONFIG"))
    support.check_configuration(config, target, ada, cxx, runtime)
    probe = support.identity_probe(ada, runtime, readelf)

    core = resolved(value("OPENCV_CROSS_CORE_PREFIX"))
    require(core != Path("/") and not inside(core, ROOT) and not inside(ROOT, core),
            "dedicated installed Core prefix outside checkout required")
    tree(core, core)
    project = core / "share/gpr/opencv_core.gpr"
    require(project.is_file(), "missing installed Core GPR project")
    require(re.search(r'for\s+Externally_Built\s+use\s+"[Tt]rue"', project.read_text()),
            "Core project must be installed/externally built")
    require((core / "include/opencv_core_module_bridge.hpp").is_file(), "missing Core bridge header")
    # An installed project closure is input, not trusted host search metadata.
    # Forbid source-tree build paths and escaped absolute/relative imports.
    projects = list((core / "share/gpr").rglob("*.gpr"))
    require((core / "share/gpr/opencv_core_shim.gpr").is_file(), "missing installed Core shim project")
    for installed in projects:
        text = re.sub(r"--[^\n]*", "", installed.read_text())
        for quoted in re.findall(r'"([^"\n]+)"', text):
            candidate = quoted[2:] if quoted.startswith(("-I", "-L")) else quoted
            if candidate.startswith("/"):
                # Compiler/runtime names are allowed only when exactly selected.
                if candidate in [ada, cxx, str(runtime), str(runtime) + "/"]:
                    continue
                require(inside(Path(candidate).resolve(), core) or inside(Path(candidate).resolve(), sysroot),
                        f"installed Core path outside validated roots: {candidate}")
                resolved(candidate)
        for imported in re.findall(r'\bwith\s+"([^"\n]+)"', text, re.IGNORECASE):
            if not imported.endswith(".gpr"):
                imported += ".gpr"
            resolved(installed.parent / imported, core)
        for directories in re.findall(
                r'for\s+(?:Source_Dirs|Object_Dir|Library_Dir|Library_ALI_Dir)\s+use\s+([^;]+);',
                text, re.IGNORECASE):
            for directory in re.findall(r'"([^"\n]+)"', directories):
                resolved(installed.parent / directory, core)
    for name in ["opencv_core_ada", "opencv_core_shim"]:
        directory = "opencv_core" if name == "opencv_core_ada" else name
        elf(resolved(core / f"lib/{directory}/lib{name}.a", core), readelf)
    # Attestations are optional; real ALI/object and link evidence is mandatory.
    identity = core / "share/opencv_core/cross-identity.json"
    recorded = json.loads(identity.read_text()) if identity.is_file() else {}
    expected = {"target": target, "runtime": str(runtime), "opencv_version": version,
                "ada_version": run([ada, "-dumpfullversion"]),
                "library_kind": "static-pic"}
    for key, item in expected.items():
        require(key not in recorded or recorded[key] == item, f"Core target identity mismatch: {key}")
    count = support.check_alis(core, probe["signature"])
    return dict(target=target, sysroot=str(sysroot), ada=ada, cxx=cxx,
                runtime=str(runtime), config=str(config), readelf=readelf,
                include=str(include), library=str(library), libraries=libraries,
                core=str(core), core_provenance=recorded, core_alis=count, version=version,
                runtime_identity=runtime_evidence, ada_probe=probe, ali_signature=probe["signature"],
                ada_flags=support.flags("ada"), cxx_flags=support.flags("cxx"),
                cflags=cflags, gprbuild=tool("OPENCV_CROSS_GPRBUILD"),
                gprinstall=tool("OPENCV_CROSS_GPRINSTALL"))


def generate(settings, work):
    require(settings.get("qualification") != "TARGET_SYSROOT_ONLY",
            "partial sysroot qualification cannot generate production configuration")
    require((work / "source-revision.txt").is_file() and work != ROOT,
            "generation requires isolated exact-revision workspace")
    output = work / "config/opencv_imgproc_install.gpr"
    require(not output.exists(), "stale target configuration")
    output.parent.mkdir(exist_ok=True)
    lines = ["-- Generated target-only configuration.", "abstract project OpenCV_Imgproc_Install is",
             'type Shim_Build_Kind is ("Static_PIC", "Relocatable", "External_Relocatable");',
             'type Cxx_Toolchain_Kind is ("GNU", "Apple_Clang");',
             'Shim_Build : Shim_Build_Kind := "Static_PIC";',
             'Cxx_Toolchain : Cxx_Toolchain_Kind := "GNU";']
    fields = dict(Include_Switch="-I" + settings["include"],
                  Library_Search_Switch="-L" + settings["library"],
                  OpenCV_Imgproc_Link_Option=settings["libraries"]["imgproc"],
                  OpenCV_Core_Link_Option=settings["libraries"]["core"],
                  Core_Shim_Link_Option="", Cxx_Runtime_Switch="-lstdc++",
                  Cxx_Driver=settings["cxx"], Cxx_Sysroot=settings["sysroot"])
    lines += [f'{key} := "{item}";' for key, item in fields.items()]
    switches = ["--sysroot=" + settings["sysroot"]] + settings["cflags"] + settings.get("cxx_flags", [])
    lines += ['Cross_Compiler_Switches := (' + ", ".join(json.dumps(s) for s in switches) + ');',
              'Cross_Linker_Switches := ("--sysroot=' + settings["sysroot"] + '");',
              "end OpenCV_Imgproc_Install;"]
    output.write_text("\n".join(lines) + "\n")


def logged(args, log, env):
    with log.open("w") as output:
        result = subprocess.run([str(arg) for arg in args], stdout=output, stderr=subprocess.STDOUT, env=env)
    if result.returncode:
        raise ConfigurationError(f"build/probe failed; original diagnostics: {log}\n{log.read_text()}", result.returncode)


def workspace(mode, destination, settings):
    require(settings.get("qualification") != "TARGET_SYSROOT_ONLY",
            "partial sysroot qualification cannot authorize production workspace")
    require(mode in ["--prepare", "--build"], "usage: --prepare|--build ABSOLUTE_WORKSPACE")
    require(Path(destination).is_absolute(), "workspace must be absolute")
    require(not re.search(r'[\s"\\]', destination), "unsafe workspace path")
    work = Path(destination)
    require(not work.exists() and not work.is_symlink(), "workspace must not already exist")
    work = work.resolve()
    for protected in [ROOT, resolved(settings["sysroot"]), resolved(settings["core"])]:
        require(not inside(work, protected) and not inside(protected, work), "workspace overlaps checkout or sysroot")
    profile = os.environ.get("OPENCV_CROSS_PROFILE", "development")
    require(profile in ["development", "release", "validation"], "invalid build profile")
    revision = support.export_source(ROOT, work)
    settings = dict(settings, work=str(work))
    generate(settings, work)
    (work / "config/opencv_imgproc_config.gpr").write_text(
        f'abstract project OpenCV_Imgproc_Config is\nBuild_Profile := "{profile}";\n'
        'Ada_Compiler_Switches := ("-gnatwa", "-gnatwe");\nend OpenCV_Imgproc_Config;\n')
    shutil.copyfile(settings["config"], work / "config/target.cgpr")
    (work / "cross-evidence.json").write_text(json.dumps(dict(settings, source_sha=revision), indent=2) + "\n")
    env = dict(os.environ, GPR_PROJECT_PATH=settings["core"] + "/share/gpr",
               OPENCV_IMGPROC_LIBRARY_TYPE="static-pic", OPENCV_CORE_LIBRARY_TYPE="static-pic")
    probe = work / "tests/fixtures/cross-reference"
    command = [settings["gprbuild"], "--config=" + str(work / "config/target.cgpr")]
    sysroot_switch = "--sysroot=" + settings["sysroot"]
    compile_switches = ["-cargs:Ada", sysroot_switch, *settings.get("ada_flags", []),
                        "-cargs:C++", sysroot_switch, *settings.get("cxx_flags", [])]
    link_switches = ["-largs", sysroot_switch, *settings.get("cxx_flags", []), "-Wl,-t",
                     *["-Wl,-rpath-link," + str(directory) for directory in
                       support.loader_directories(Path(settings["sysroot"]), settings["target"])]]
    logged(command + ["-P", str(probe / "probe.gpr"), "-p", "-v", "-R"] + compile_switches + link_switches,
           work / "toolchain-probe.log", env)
    support.check_trace(work / "toolchain-probe.log", settings)
    support.executable_evidence(probe / "bin/probe", settings)
    evidence = elf(probe / "bin/probe", settings["readelf"])
    evidence += elf(probe / "obj/cxx_probe.o", settings["readelf"])
    (work / "toolchain-probe-elf.log").write_text(evidence)
    opencv_probe = work / "opencv-probe"
    logged([settings["cxx"], sysroot_switch, *settings.get("cxx_flags", []),
            "-I" + settings["include"], str(probe / "opencv_link_probe.cpp"),
            "-o", str(opencv_probe), settings["libraries"]["imgproc"], settings["libraries"]["core"],
            *link_switches[1:]], work / "opencv-probe.log", env)
    (work / "opencv-probe-evidence.json").write_text(json.dumps(
        support.executable_evidence(opencv_probe, settings), indent=2) + "\n")
    print("TARGET_PROBE_QUALIFIED (not production or execution qualification)")
    if mode == "--build":
        logged(command + ["-P", str(work / "opencv_imgproc.gpr"), "-p", "-v",
                          *compile_switches],
               work / "production-build.log", env)
        support.check_trace(work / "production-build.log", settings)
        support.check_alis(work / "obj", settings["ali_signature"])
        for path in list((work / "obj").rglob("*.o")) + list((work / "lib").glob("*.a")):
            elf(path, settings["readelf"])
        for project in ["opencv_imgproc_shim", "opencv_imgproc"]:
            logged([settings["gprinstall"], "--config=" + str(work / "config/target.cgpr"),
                    "-P", str(work / (project + ".gpr")), "-p", "--prefix=" + str(work / "install")],
                   work / (project + "-install.log"), env)
        notices = work / "install/share/doc/opencv_imgproc"
        notices.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(work / "LICENSE", notices / "LICENSE")
        print("Imgproc production build/install passed; Core and runtime gates remain independent")
    print(f"Cross workspace: {work}\nSource revision: {revision}")


def main():
    require(len(sys.argv) >= 3, "explicit configure --check or workspace operation required")
    operation = sys.argv[1]
    require(operation in ["configure", "workspace"], "unknown cross operation")
    partial = operation == "configure" and sys.argv[2:] == ["--check-sysroot"]
    settings = validate(sysroot_only=partial)
    if operation == "configure":
        require(partial or sys.argv[2:] == ["--check"], "configuration generation is restricted to workspace entry point")
        print(json.dumps(settings, indent=2))
    else:
        require(len(sys.argv) == 4, "usage: --prepare|--build ABSOLUTE_WORKSPACE")
        workspace(sys.argv[2], sys.argv[3], settings)


if __name__ == "__main__":
    try:
        main()
    except (ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(getattr(failure, "returncode", 1))