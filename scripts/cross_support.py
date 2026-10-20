"""Production cross-build checks shared by the existing backend and installer.

GNATLS bootstrap follows merged Core PR #92. Symbol compatibility is checked
on actual linked requirements, not the set of versions a compiler can provide.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile


def api():
    # Lazy import avoids a second backend and permits the legacy script entry.
    import cross_configuration
    return cross_configuration


def flags(language):
    cross = api()
    items = json.loads(os.environ.get(f"OPENCV_CROSS_{language.upper()}_FLAGS", "[]"))
    cross.require(isinstance(items, list), "CPU flags must be a JSON array")
    for item in items:
        cross.require(isinstance(item, str) and re.fullmatch(
            r"-m(?:arch|cpu|tune)=[A-Za-z0-9_.+\-]+|-mabi=lp64", item),
            f"unsupported {language} flag: {item}")
    return items


def runtime_identity(ada, runtime):
    cross = api()
    answer = cross.run([ada, "-print-file-name=adalib"])
    if Path(answer).is_absolute() and Path(answer).is_dir():
        cross.require(cross.resolved(answer) == cross.resolved(runtime / "adalib"),
                      "Ada runtime differs from compiler runtime")
        return dict(method="compiler", adalib=str(cross.resolved(answer)))
    compiler = cross.resolved(ada)
    match = re.fullmatch(r"(.*?)gcc(-[0-9.]+)?", compiler.name)
    cross.require(match, f"cannot derive selected GNATLS from {compiler}")
    gnatls = compiler.with_name(match[1] + "gnatls" + (match[2] or ""))
    cross.require(gnatls.is_file() and os.access(gnatls, os.X_OK)
                  and gnatls.resolve().parent == compiler.parent,
                  f"matching GNATLS unavailable: {gnatls}")
    output = cross.run([str(gnatls), "-v"], env=dict(os.environ, LC_ALL="C"))
    sections, seen, section = {"Source": [], "Object": []}, set(), None
    for line in output.splitlines():
        line = line.strip()
        header = re.fullmatch(r"(Source|Object) Search Path\s*:", line)
        if header:
            section = header[1]
            cross.require(section not in seen, "duplicate GNATLS section")
            seen.add(section)
        elif re.match(r"[A-Za-z].*Search Path\s*:", line):
            cross.require(not line.startswith(("Source", "Object")), "malformed GNATLS section")
            section = None
        elif section and line and line != "<Current_Directory>":
            cross.require(Path(line).is_absolute(), "nonabsolute GNATLS directory")
            sections[section].append(str(cross.resolved(line)))
    for kind, directory in [("Source", "adainclude"), ("Object", "adalib")]:
        cross.require(sections[kind] and all(
            item == str(cross.resolved(runtime / directory)) for item in sections[kind]),
            f"Ada runtime differs from GNATLS {kind} search paths")
    return dict(method="gnatls", path=str(gnatls), sections=sections, output=output)


def ali_signature(path):
    cross = api()
    lines = Path(path).read_text().splitlines()
    cross.require(lines and re.fullmatch(r'V "GNAT Lib v[^"\n]+"', lines[0]),
                  f"invalid complete ALI version signature: {path}")
    return lines[0]


def check_alis(root, signature):
    cross = api()
    alis = sorted(Path(root).rglob("*.ali"))
    cross.require(alis, f"missing target ALIs: {root}")
    for path in alis:
        cross.require(ali_signature(path) == signature, f"mixed GNAT runtime/compiler ALI: {path}")
    return len(alis)


def identity_probe(ada, runtime, readelf):
    cross = api()
    # Retain this directory on any failure, just like production diagnostics.
    work = Path(tempfile.mkdtemp(prefix="imgproc-ada-identity-"))
    try:
        source = work / "identity_probe.adb"
        source.write_text("procedure Identity_Probe is begin null; end Identity_Probe;\n")
        cross.logged([ada, "--RTS=" + str(runtime), *flags("ada"), "-c", str(source),
                      "-o", str(work / "identity_probe.o")], work / "compile.log", dict(os.environ))
        cross.elf(work / "identity_probe.o", readelf)
        signature = ali_signature(work / "identity_probe.ali")
        cross.require(signature == ali_signature(runtime / "adalib/system.ali"),
                      "fresh Ada probe ALI differs from selected runtime")
        result = dict(signature=signature, compiler_sha256=cross.digest(ada),
                      runtime_sha256=cross.digest(runtime / "adalib/libgnat.a"),
                      compile_log=(work / "compile.log").read_text())
    except BaseException:
        print(f"Ada identity probe retained: {work}", flush=True)
        raise
    shutil.rmtree(work)
    return result


def check_configuration(config, target, ada, cxx, runtime):
    cross = api()
    text = re.sub(r"--[^\n]*", "", Path(config).read_text())
    selected = re.search(r'for\s+Target\s+use\s+"([^"]+)"', text, re.I)
    canonical = re.sub(r"-gnu$", "", target)
    cross.require(selected and selected[1] in {target, canonical}, "GPR target mismatch")
    for language, driver in [("Ada", ada), ("C++", cxx)]:
        match = re.search(r'for\s+Driver\s*\(\s*"' + re.escape(language)
                          + r'"\s*\)\s+use\s+"([^"]+)"', text, re.I)
        cross.require(match and Path(match[1]).is_absolute()
                      and Path(match[1]).resolve() == Path(driver).resolve(),
                      f"GPR {language} compiler mismatch")
    match = re.search(r'for\s+Runtime(?:_Dir)?\s*\(\s*"Ada"\s*\)\s+use\s+"([^"]+)"', text, re.I)
    cross.require(match and Path(match[1]).resolve() == Path(runtime).resolve(),
                  "GPR Ada runtime mismatch")
    # Binder/linker selection is additionally authenticated in verbose real links.
    cross.require(re.search(r"package\s+Binder\s+is", text, re.I)
                  and re.search(r"package\s+Linker\s+is", text, re.I),
                  "GPR binder/linker configuration missing")


def loader_directories(sysroot, target):
    cross = api()
    entries = []
    def read(path, depth=0):
        cross.require(depth < 9, "recursive target ld.so.conf")
        if not path.is_file():
            return
        cross.resolved(path, sysroot)
        for line in path.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if line.startswith("include "):
                for item in sorted(sysroot.glob(line.split(None, 1)[1].lstrip("/"))):
                    read(item, depth + 1)
            elif line:
                entries.append(line)
    read(sysroot / "etc/ld.so.conf")
    entries += [f"/lib/{target}", f"/usr/lib/{target}", "/lib64", "/usr/lib64", "/lib", "/usr/lib"]
    result = []
    for entry in entries:
        cross.require(entry.startswith("/"), "relative target loader directory")
        path = sysroot / entry.lstrip("/")
        if path.is_dir() and path not in result:
            result.append(cross.resolved(path, sysroot))
    return result


def check_versions(closure, readelf):
    cross = api()
    count = 0
    providers = {}
    for path, details in closure.items():
        current = None
        for line in cross.run([readelf, "-V", path]).splitlines():
            file = re.search(r"\bFile:\s+(\S+)", line)
            if file:
                current = file[1]
            version = re.search(r"\bName:\s+(\S+)\s+Flags:", line)
            if current and version:
                cross.require(current in details["needed"], "version dependency not in DT_NEEDED")
                provider = details["needed"][current]
                if provider not in providers:
                    definitions = cross.run([readelf, "-V", provider]).split("Version definition section", 1)
                    providers[provider] = set(re.findall(r"Name:\s+(\S+)", definitions[1].split(
                        "Version needs section", 1)[0])) if len(definitions) == 2 else set()
                provided = providers[provider]
                cross.require(version[1] in provided,
                              f"{path} needs {version[1]} absent from target {current}")
                count += 1
    return count


def executable_evidence(path, settings):
    cross = api()
    readelf, sysroot = settings["readelf"], Path(settings["sysroot"])
    header = cross.elf(path, readelf)
    program = cross.run([readelf, "-l", str(path)])
    interpreter = re.search(r"Requesting program interpreter: ([^\]]+)\]", program)
    cross.require(interpreter, "missing target interpreter")
    cross.resolved(sysroot / interpreter[1].lstrip("/"), sysroot)
    dynamic = cross.run([readelf, "-d", str(path)])
    cross.require(not re.search(r"\((?:RPATH|RUNPATH)\)", dynamic), "unapproved RPATH/RUNPATH")
    closure = cross.dependency_closure([path], sysroot, readelf, generated=Path(path))
    return dict(elf=header + program + dynamic, closure=closure,
                symbol_versions=check_versions(closure, readelf))


def link_inputs(log, settings, work, archives=()):
    """Authenticate -Wl,-t inputs, not merely the driver's advertised search.

    Only named compiler support/startup files may live outside the sysroot,
    installed archives and this consumer's objects. OpenCV never may.
    """
    cross = api()
    trusted = {Path(path).resolve() for path in archives}
    names = ["Scrt1.o", "crt1.o", "crti.o", "crtn.o", "crtbegin.o", "crtend.o",
             "crtbeginS.o", "crtendS.o", "libgcc.a", "libgcc_s.so", "libgcc_s.so.1", "libstdc++.so"]
    for name in names:
        answer = cross.run([settings["cxx"], "--sysroot=" + settings["sysroot"], "-print-file-name=" + name])
        if Path(answer).is_absolute() and Path(answer).is_file():
            trusted.add(cross.resolved(answer))
    inputs = {}
    for line in Path(log).read_text().splitlines():
        item = line.strip()
        if not item.startswith("/") or any(character.isspace() for character in item):
            continue
        path = Path(item)
        if path.suffix not in {".o", ".a", ".so"} and ".so." not in path.name:
            continue
        actual = cross.resolved(path)
        cross.require(actual in trusted or cross.inside(actual, Path(settings["sysroot"]))
                      or cross.inside(actual, work), f"unapproved actual linker input: {path}")
        # GCC/libc link scripts are text, their selected ELF inputs appear in
        # the same trace and are individually checked below.
        if actual.read_bytes()[:4] == b"\x7fELF" or actual.suffix in {".o", ".a"}:
            cross.elf(actual, settings["readelf"])
        inputs[str(actual)] = cross.digest(actual)
    cross.require(inputs, f"no actual linker inputs recorded: {log}")
    return inputs


def check_trace(log, settings, installed_library_dirs=()):
    """Consumer-only -L exceptions are exact, never a /usr/local whitelist."""
    cross = api()
    libraries = set()
    for item in installed_library_dirs:
        item = Path(item)
        cross.require(item.is_absolute() and item.parent.name == "lib"
                      and ".." not in item.parts and item.resolve() == item,
                      f"invalid installed library directory: {item}")
        cross.resolved(item, item.parent.parent)
        libraries.add(item)
    count = 0
    tools = []
    for line in Path(log).read_text().splitlines():
        words = shlex.split(line) if line.strip().startswith("/") else []
        if not words:
            continue
        name = Path(words[0]).name
        if not re.fullmatch(r"[\w.+-]*(?:gcc|g\+\+|gnatbind|gnatlink|ar|ranlib|ld)(?:-[0-9.]+)?", name):
            continue
        executable = Path(words[0])
        if "gcc" in name or "g++" in name:
            cross.require(str(executable) in {settings["ada"], settings["cxx"]},
                          f"unsupplied driver: {executable}")
        else:
            cross.require(executable.parent in {Path(settings["ada"]).parent, Path(settings["cxx"]).parent}
                          and name.startswith(settings["target"] + "-"),
                          f"unsupplied binder/archiver/linker: {executable}")
        tools.append(str(executable))
        for word in words[1:]:
            cross.require("x86_64" not in word, f"host architecture in trace: {word}")
            if word.startswith(("-I/", "-L/")):
                path = Path(word[2:])
                installed = word.startswith("-L") and path in libraries and path.resolve() == path and ".." not in path.parts
                roots = [Path(settings["sysroot"]), Path(settings["runtime"])]
                if settings.get("work"):
                    roots.append(Path(settings["work"]))
                if word.startswith("-I"):
                    roots += [Path(settings["core"]), Path(settings.get("work", settings["core"]))]
                cross.require(installed or any(cross.inside(path.resolve(), root) for root in roots),
                              f"unapproved include/library directory: {word}")
        count += "-c" in words
    cross.require(count, f"no compile commands: {log}")
    return dict(compilations=count, tools=sorted(set(tools)))


def export_source(root, work):
    cross = api()
    if (root / ".git").exists():
        git = ["git", "-c", f"safe.directory={root}", "-C", str(root)]
        cross.require(cross.resolved(cross.run(git + ["rev-parse", "--show-toplevel"])) == root,
                      "source is not Git root")
        cross.require(not cross.run(git + ["status", "--porcelain", "--untracked-files=all"]),
                      "source revision must be clean")
        revision = cross.run(git + ["rev-parse", "HEAD"])
        work.mkdir(parents=True)
        archive = work / "source.tar"
        cross.run(git + ["archive", "--output=" + str(archive), revision])
        import tarfile
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                cross.require(member.isfile() or member.isdir() or member.issym(), "unsafe archive member")
                cross.require(cross.inside((work / member.name).resolve(), work), "archive traversal")
                if member.issym():
                    cross.require(cross.inside((work / member.name).parent.joinpath(member.linkname).resolve(), work),
                                  "archive symlink escape")
            source.extractall(work, **({"filter": "data"} if hasattr(tarfile, "data_filter") else {}))
        archive.unlink()
    else:
        cross.require(os.environ.get("OPENCV_CROSS_SOURCE_ROOT"), "Git-free sources require explicit --source-root")
        excluded = {".git", "alire", "config", "obj", "lib", "bin", "__pycache__", ".venv"}
        generated = re.compile(r".*\.(?:ali|o|a|so(?:\.[0-9.]+)?|dll|exe|dylib|cgpr|pyc|lexch|bexch)$")
        def ignore(directory, names):
            return [name for name in names if name in excluded or generated.fullmatch(name)]
        for directory, directories, files in os.walk(root, followlinks=False):
            directories[:] = [name for name in directories if name not in ignore(directory, directories)]
            for name in directories + files:
                if name in ignore(directory, [name]):
                    continue
                path = Path(directory) / name
                if path.is_symlink():
                    target = cross.resolved(path, root)
                    cross.require(not path.is_dir() and not any(part in excluded for part in target.relative_to(root).parts)
                                  and not generated.fullmatch(target.name), "source symlink to generated state")
        shutil.copytree(root, work, ignore=ignore, symlinks=False)
        identity = hashlib.sha256()
        for path in sorted(work.rglob("*")):
            if path.is_file():
                identity.update(str(path.relative_to(work)).encode() + b"\0" + path.read_bytes() + b"\0")
        revision = "staged-sha256:" + identity.hexdigest()
    (work / "config").mkdir(exist_ok=True)
    # Generated native configuration is never imported, even from Git.
    for path in (work / "config").glob("*.gpr"):
        path.unlink()
    (work / "source-revision.txt").write_text(revision + "\n")
    return revision