"""External AdaCore/post-Yocto preflight, NOT compilation qualification.

No SDK script is sourced, CC/CXX is never inferred, and BitBake is never used.
Provenance is a caller assertion, not proof of toolchain or sysroot origin.
"""
import json
import os
from pathlib import Path
import re
import shutil
import sys

import cross_configuration as cross


def switches(name):
    items = json.loads(os.environ.get(name, "[]"))
    cross.require(isinstance(items, list), f"{name}: expected JSON array")
    for item in items:
        cross.require(isinstance(item, str) and re.fullmatch(
            r"-m(?:arch|cpu|tune)=[A-Za-z0-9_.+\-]+|-mabi=lp64", item),
            f"{name}: unsupported compiler/linker flag: {item}")
    return items


def preflight():
    # Inventory requires explicit drivers, not Yocto CC/CXX strings.
    tools = {}
    for name in ["ADA", "CXX", "GPRBUILD", "GPRINSTALL"]:
        path = cross.tool("OPENCV_CROSS_" + name)
        tools[name.lower()] = dict(path=path, sha256=cross.digest(path),
                                  version=cross.run([path, "--version"]))
    flags = {name: switches("OPENCV_CROSS_" + name.upper() + "_FLAGS")
             for name in ["ada", "cxx"]}
    settings = cross.validate(sysroot_only=True, independent_toolchains=True)
    for name in ["ada", "cxx"]:
        compiler = tools[name]["path"]
        tools[name]["search_dirs"] = cross.run([compiler, "-print-search-dirs"])
        linker = shutil.which(cross.run([compiler, "-print-prog-name=ld"]))
        cross.require(linker, "compiler-selected linker unavailable")
        tools[name]["linker"] = dict(path=linker, sha256=cross.digest(linker),
                                     version=cross.run([linker, "--version"]))
    provenance_path = cross.resolved(cross.value("OPENCV_CROSS_YOCTO_PROVENANCE"))
    provenance = json.loads(provenance_path.read_text())
    cross.require(isinstance(provenance, dict), "Yocto provenance must be an object")
    cross.require(provenance.get("release") == "scarthgap", "Yocto release must be scarthgap")
    for name in ["build_identity", "image_identity", "export_method"]:
        cross.require(isinstance(provenance.get(name), str) and provenance[name].strip(),
                      f"missing Yocto provenance: {name}")
    cross.require(provenance.get("sysroot") == settings["sysroot"],
                  "Yocto provenance sysroot mismatch")
    config = cross.resolved(cross.value("OPENCV_CROSS_GPR_CONFIG"))
    text = re.sub(r"--[^\n]*", "", config.read_text())
    for token, diagnostic in [
            (f'for Target use "{settings["target"]}";', "GPR target mismatch"),
            (f'"{settings["ada"]}"', "GPR Ada compiler mismatch"),
            (f'"{settings["cxx"]}"', "GPR C++ compiler mismatch"),
            (f'"{settings["runtime"]}/"', "GPR Ada runtime mismatch"),
            ('for Driver use Compiler\'Driver ("C++");', "GPR linker mismatch")]:
        cross.require(token in text, diagnostic)
    dispositions = ["EXTERNAL_INPUT_PREFLIGHT_ONLY", "TARGET_RUNTIME_PENDING"]
    if not os.environ.get("OPENCV_CROSS_CORE_PREFIX"):
        dispositions.append("CORE_PREREQUISITE_BLOCKED")
    else:
        cross.validate(independent_toolchains=True)
        dispositions.append("CORE_PREFLIGHT_ONLY")
    return dict(tools=tools, requested_flags=flags, target_inputs=settings,
                runtime_archive_sha256=cross.digest(Path(settings["runtime"]) / "adalib/libgnat.a"),
                gpr_config_sha256=cross.digest(config),
                provenance=dict(caller_assertion=provenance, sha256=cross.digest(provenance_path)),
                dispositions=dispositions, production_qualified=False,
                unverified=["AdaCore vendor provenance", "compiler flag support",
                    "Ada compiler/runtime compilation compatibility", "Yocto provenance",
                    "actual Ada/C++ compile/link and linker input traces",
                    "glibc/GLIBCXX/CXXABI requirements", "production shim compilation",
                    "production build/install", "deployment closure", "target execution"])


if __name__ == "__main__":
    try:
        cross.require(sys.argv[1:] == ["--check"], "usage: adacore_cross.py --check (preflight only)")
        print(json.dumps(preflight(), indent=2))
    except (cross.ConfigurationError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)