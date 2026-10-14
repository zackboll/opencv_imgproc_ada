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
import tarfile


ROOT = Path(__file__).resolve().parents[1]


class ConfigurationError(Exception):
    """A failed cross prerequisite; never select a host substitute."""


def require(condition, message):
    if not condition:
        raise ConfigurationError(message)


def run(args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    require(result.returncode == 0,
            f"command failed: {args}\n{result.stdout}{result.stderr}")
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


def validate():
    target = value("OPENCV_CROSS_TARGET")
    run(["sh", str(ROOT / "scripts/validate_cross_target.sh"), target])
    sysroot = resolved(value("ENV_PREFIX"))
    require(sysroot.is_dir() and sysroot != Path("/"), "dedicated target sysroot required")
    for name in ["CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "LIBRARY_PATH",
                 "GCC_EXEC_PREFIX", "COMPILER_PATH", "ADA_INCLUDE_PATH",
                 "ADA_OBJECTS_PATH", "GPR_PROJECT_PATH", "ADA_PROJECT_PATH"]:
        require(not os.environ.get(name), f"cross mode requires empty {name}")
    ada, cxx = tool("OPENCV_CROSS_ADA"), tool("OPENCV_CROSS_CXX")
    for compiler in [ada, cxx]:
        require(run([compiler, "-dumpmachine"]) == target, f"compiler target mismatch: {compiler}")
    readelf = tool("OPENCV_CROSS_READELF", "readelf")
    runtime = resolved(value("OPENCV_CROSS_RUNTIME"))
    require((runtime / "adainclude").is_dir() and (runtime / "adalib").is_dir(),
            "target Ada runtime must contain adainclude and adalib")
    require(resolved(run([ada, "-print-file-name=adalib"])) == resolved(runtime / "adalib"),
            "Ada runtime differs from compiler runtime")
    elf(resolved(runtime / "adalib/libgnat.a"), readelf)
    config = resolved(value("OPENCV_CROSS_GPR_CONFIG"))
    # Reject comments before checking actual declarations. Compilation probes
    # independently check the selected drivers; text checks alone are not proof.
    gpr = re.sub(r"--[^\n]*", "", config.read_text())
    for declaration, message in [
            (f'for Target use "{target}";', "GPR target mismatch"),
            (f'"{ada}"', "GPR Ada compiler mismatch"),
            (f'"{cxx}"', "GPR C++ compiler mismatch"),
            (f'"{runtime}/"', "GPR Ada runtime mismatch"),
            ('for Driver use Compiler\'Driver ("C++");', "GPR linker mismatch")]:
        require(declaration in gpr, message)
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
    for flag in flags:
        if flag.startswith(("-I", "-L")):
            directory = resolved(flag[2:], sysroot)
            require(directory.is_dir(), "missing pkg-config dependency directory")
            tree(directory, sysroot)
        elif flag.startswith("/"):
            elf(resolved(flag, sysroot), readelf)
        else:
            require(re.fullmatch(r"-l(?:opencv_core|opencv_imgproc|stdc\+\+)|-D[A-Za-z0-9_=]+|-pthread", flag),
                    f"unsupported target pkg-config flag: {flag}")
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
            require(f"libopencv_{module}.so.{abi[0]}{int(abi[1]):02d}" in dynamic,
                    f"OpenCV {module} SONAME/version mismatch")
    for name in ["libc.so.6", "libstdc++.so.6"]:
        found = list(sysroot.rglob(name))
        require(found, f"missing target runtime library: {name}")
        for path in found:
            elf(resolved(path, sysroot), readelf)

    core = resolved(value("OPENCV_CROSS_CORE_PREFIX"), sysroot)
    tree(core, sysroot)
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
                resolved(candidate, sysroot)
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
        elf(resolved(core / f"lib/{directory}/lib{name}.a", sysroot), readelf)
    # Core builds are a separate release gate. Metadata is an explicit attestation
    # from that build, not evidence that this wrapper rebuilt Core successfully.
    identity = core / "share/opencv_core/cross-identity.json"
    require(identity.is_file(), "missing Core target build identity")
    recorded = json.loads(identity.read_text())
    expected = {"target": target, "runtime": str(runtime), "opencv_version": version,
                "ada_version": run([ada, "-dumpfullversion"]),
                "gpr_config_sha256": digest(config), "library_kind": "static-pic"}
    for key, item in expected.items():
        require(recorded.get(key) == item, f"Core target identity mismatch: {key}")
    require(re.fullmatch(r"[0-9a-f]{40}", recorded.get("source_sha", "")), "invalid Core source SHA")
    # ALIs must come from the same GNAT version; inspect all installed units.
    alis = list(core.rglob("*.ali"))
    require(alis, "missing Core target ALIs")
    for ali in alis:
        first = ali.read_text().splitlines()[0]
        # GNAT 12 records its ALI format major, not GCC's full patch version.
        # Full compiler/runtime identity is checked separately in the attestation.
        require(first == f'V "GNAT Lib v{expected["ada_version"].split(".")[0]}"',
                f"mixed GNAT runtime/compiler ALI: {ali}")
    return dict(target=target, sysroot=str(sysroot), ada=ada, cxx=cxx,
                runtime=str(runtime), config=str(config), readelf=readelf,
                include=str(include), library=str(library), libraries=libraries,
                core=str(core), core_sha=recorded["source_sha"], version=version,
                cflags=cflags, gprbuild=tool("OPENCV_CROSS_GPRBUILD"),
                gprinstall=tool("OPENCV_CROSS_GPRINSTALL"))


def generate(settings, work):
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
    switches = ["--sysroot=" + settings["sysroot"]] + settings["cflags"]
    lines += ['Cross_Compiler_Switches := (' + ", ".join(json.dumps(s) for s in switches) + ');',
              'Cross_Linker_Switches := ("--sysroot=' + settings["sysroot"] + '");',
              "end OpenCV_Imgproc_Install;"]
    output.write_text("\n".join(lines) + "\n")


def logged(args, log, env):
    with log.open("w") as output:
        result = subprocess.run(args, stdout=output, stderr=subprocess.STDOUT, env=env)
    require(result.returncode == 0, f"build/probe failed; original diagnostics: {log}\n{log.read_text()}")


def workspace(mode, destination, settings):
    require(mode in ["--prepare", "--build"], "usage: --prepare|--build ABSOLUTE_WORKSPACE")
    require(Path(destination).is_absolute(), "workspace must be absolute")
    require(not re.search(r'[\s"\\]', destination), "unsafe workspace path")
    work = Path(destination)
    require(not work.exists() and not work.is_symlink(), "workspace must not already exist")
    work = work.resolve()
    for protected in [ROOT, resolved(settings["sysroot"])]:
        require(not inside(work, protected) and not inside(protected, work), "workspace overlaps checkout or sysroot")
    require(not run(["git", "-C", str(ROOT), "status", "--porcelain"]), "source revision must be clean")
    revision = run(["git", "-C", str(ROOT), "rev-parse", "HEAD"])
    profile = os.environ.get("OPENCV_CROSS_PROFILE", "development")
    require(profile in ["development", "release", "validation"], "invalid build profile")
    # All preflight and destination checks have passed before mutation.
    work.mkdir(parents=True)
    archive = work / "source.tar"
    run(["git", "-C", str(ROOT), "archive", "--output=" + str(archive), revision])
    with tarfile.open(archive) as source:
        # Debian's original Python 3.11 predates extraction filters. Git archives
        # contain files/directories/symlinks only; validate destinations explicitly
        # and reject hard links/devices before extracting even trusted Git input.
        for member in source.getmembers():
            require(inside((work / member.name).resolve(), work), "archive path escapes workspace")
            require(member.isfile() or member.isdir() or member.issym(), "unsafe archive member")
            if member.issym():
                require(inside((work / member.name).parent.joinpath(member.linkname).resolve(), work),
                        "archive symlink escapes workspace")
        if hasattr(tarfile, "data_filter"):
            source.extractall(work, filter="data")
        else:
            source.extractall(work)
    archive.unlink()
    (work / "source-revision.txt").write_text(revision + "\n")
    generate(settings, work)
    (work / "config/opencv_imgproc_config.gpr").write_text(
        f'abstract project OpenCV_Imgproc_Config is\nBuild_Profile := "{profile}";\n'
        'Ada_Compiler_Switches := ("-gnat2022", "-gnatwa", "-gnatwe");\nend OpenCV_Imgproc_Config;\n')
    shutil.copyfile(settings["config"], work / "config/target.cgpr")
    (work / "cross-evidence.json").write_text(json.dumps(dict(settings, source_sha=revision), indent=2) + "\n")
    env = dict(os.environ, GPR_PROJECT_PATH=settings["core"] + "/share/gpr",
               OPENCV_IMGPROC_LIBRARY_TYPE="static-pic", OPENCV_CORE_LIBRARY_TYPE="static-pic")
    probe = work / "tests/fixtures/cross-reference"
    command = [settings["gprbuild"], "--config=" + str(work / "config/target.cgpr")]
    sysroot_switch = "--sysroot=" + settings["sysroot"]
    logged(command + ["-P", str(probe / "probe.gpr"), "-p", "-v", "-cargs:Ada", sysroot_switch,
                      "-cargs:C++", sysroot_switch, "-largs", sysroot_switch],
           work / "toolchain-probe.log", env)
    trace = (work / "toolchain-probe.log").read_text()
    require(settings["ada"] in trace and settings["cxx"] in trace, "GPR trace compiler/linker mismatch")
    evidence = elf(probe / "bin/probe", settings["readelf"])
    evidence += elf(probe / "obj/cxx_probe.o", settings["readelf"])
    (work / "toolchain-probe-elf.log").write_text(evidence)
    print("TARGET_PROBE_QUALIFIED (not production or execution qualification)")
    if mode == "--build":
        logged(command + ["-P", str(work / "opencv_imgproc.gpr"), "-p", "-v",
                          "-cargs:Ada", sysroot_switch, "-cargs:C++", sysroot_switch],
               work / "production-build.log", env)
        for path in list((work / "obj").rglob("*.o")) + list((work / "lib").glob("*.a")):
            elf(path, settings["readelf"])
        logged([settings["gprinstall"], "--config=" + str(work / "config/target.cgpr"),
                "-P", str(work / "opencv_imgproc.gpr"), "-p", "-r", "--prefix=" + str(work / "install")],
               work / "production-install.log", env)
        print("Imgproc production build/install passed; Core and runtime gates remain independent")
    print(f"Cross workspace: {work}\nSource revision: {revision}")


def main():
    require(len(sys.argv) >= 3, "explicit configure --check or workspace operation required")
    operation = sys.argv[1]
    require(operation in ["configure", "workspace"], "unknown cross operation")
    settings = validate()
    if operation == "configure":
        require(sys.argv[2:] == ["--check"], "configuration generation is restricted to workspace entry point")
        print(json.dumps(settings, indent=2))
    else:
        require(len(sys.argv) == 4, "usage: --prepare|--build ABSOLUTE_WORKSPACE")
        workspace(sys.argv[2], sys.argv[3], settings)


if __name__ == "__main__":
    try:
        main()
    except (ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(1)