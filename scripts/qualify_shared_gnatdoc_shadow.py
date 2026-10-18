#!/usr/bin/env python3
"""Read-only GNATDOC-008 qualification; never writes the consumer _site.

Authority updates are deliberately NOT a command of this runner. The checked-in
GNATDOC-005/007 contracts must be reviewed independently when inputs change.
All generated sites, tool logs and build products belong to a new workspace.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).absolute().parents[1]
BASE = "9ce22ae5ab70008e1147475a9e6d7baef82f1df0"
OLD_ENHANCER = "f52dcfe37dc2819d86e72e1c38425e5e49d914eb"
ENHANCER = "53a321915da2c5a02a54581040673b61f8595b25"
PR_START = "f2989da6c6a593f6196d1d989be0b2d126743dc6"
CORE = "386c5360ac51f2b62e522853d94290aec4ee14a0"
CONFIG = "docs/shared-gnatdoc-shadow.toml"
EVIDENCE = "docs/evidence/gnatdoc008"
CURRENT_EVIDENCE = "docs/evidence/gnatdoc008c"
TRANSITION = CURRENT_EVIDENCE + "/authority-transition.json"
TRANSITION_SHA256 = "bf399766834fd80fdbf359486abcd504d2e290b59244dda5097e01e16e770bab"
TRUST = {
    "authority.json": "9df0e47850828534fb250432baebfc8a36d6e20dd3e7d476189568dd14eebf5e",
    "authored.json": "c7f5bb0ad8afe4c8d530a2bcf04c8a9ba243c016d6500e251005c95e9858727c",
    "consumer-input.json": "aff70e359331e95951465bcd1e34f2048db6558eca4dbd00136e80af5cb02be4",
    "core-input.json": "c8512e0ff729d9bcc2903a144384288756be8da93fa591facddf6f0461fed2f4",
    "core-types.json": "eaf814b7e7b66cc57d856e861420b4c049e0f2cdfb5f2b7d94dc6604f85e06a4",
}
GNATDOC = "GNATdoc 26.0.0 (20260415)"
EXAMPLES = ("filtering_and_transforms", "color_and_representation",
            "features_and_analysis", "segmentation_and_contours",
            "matching_and_registration")
# Exact GNATDOC-005 acquisition harness for Core 0.4.1 (not production files).
CORE_API = '''with "config/opencv_core_config.gpr";
with "docs_internal.gpr";
project Docs_API is
   for Languages use ("Ada");
   for Source_Dirs use ("src");
   for Object_Dir use "obj/docs";
   package Compiler is
      for Default_Switches ("Ada") use OpenCV_Core_Config.Ada_Compiler_Switches;
   end Compiler;
   package Documentation is
      for Excluded_Project_Files use
        ("docs_internal.gpr", "config/opencv_core_config.gpr");
   end Documentation;
end Docs_API;
'''
CORE_INTERNAL = '''project Docs_Internal is
   for Languages use ("Ada");
   for Source_Dirs use ("src/internal");
   for Object_Dir use "obj/docs-internal";
end Docs_Internal;
'''


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe(path):
    path = Path(path).absolute()
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            f"symlink path: {path}")
    if path.is_dir():
        require(not any(p.is_symlink() for p in path.rglob("*")),
                f"symlink below: {path}")
    return path


def hashes(root):
    root = safe(root)
    require(root.is_dir(), f"missing directory: {root}")
    return {p.relative_to(root).as_posix(): digest(p.read_bytes())
            for p in sorted(root.rglob("*")) if p.is_file()}


def write_json(path, data):
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")


def read_json(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(safe(path).read_text(), object_pairs_hook=pairs)


def check_files(root, expected):
    safe(root)
    for name, sha in expected.items():
        path = safe(root / name)
        require(path.is_file() and digest(path.read_bytes()) == sha,
                f"authority mismatch: {name}")


def dependency(lock):
    states = [x for x in tomllib.loads(lock.read_text())["solution"]["state"]
              if x["crate"] == "opencv_core"]
    require(len(states) == 1, "Core resolution missing or ambiguous")
    state = states[0]
    release = state["release"]
    origin = release["origin"]
    require(not state["pinned"] and release["version"] == "0.4.1"
            and origin == {"commit": CORE,
                           "url": "git+https://github.com/zackboll/opencv_core_ada.git"},
            "unqualified Core resolution/origin")
    return release


class Session:
    def __init__(self, workspace):
        self.workspace = workspace
        self.commands = []

    def run(self, args, cwd, *, accepted=(0,)):
        args = [str(a) for a in args]
        result = subprocess.run(args, cwd=cwd, env={**os.environ, "DOC_PYTHON": sys.executable},
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        number = len(self.commands)
        logfile = self.workspace / f"command-{number:03}.log"
        logfile.write_text(result.stdout)
        self.commands.append({"argv": args, "cwd": str(cwd), "exit_status": result.returncode,
                              "log": logfile.name, "sha256": digest(logfile.read_bytes())})
        write_json(self.workspace / "commands.json", self.commands)
        require(result.returncode in accepted,
                f"command failed ({result.returncode}): {args}; see {logfile}")
        return result.stdout.strip()

    def export(self, source, sha, destination):
        safe(source)
        self.run(["git", "clone", "--no-hardlinks", "--no-checkout", source, destination],
                 self.workspace)
        self.run(["git", "checkout", "--detach", sha], destination)
        require(self.run(["git", "rev-parse", "HEAD"], destination) == sha,
                "checkout revision mismatch")


def provenance(session, enhancer):
    safe(enhancer)
    require(session.run(["git", "rev-parse", "HEAD"], enhancer) == ENHANCER,
            "incorrect shared enhancer SHA")
    require(session.run(["git", "status", "--porcelain", "--untracked-files=no"], enhancer) == "",
            "modified enhancer checkout")
    session.run(["git", "symbolic-ref", "-q", "HEAD"], enhancer, accepted=(1,))
    origin = session.run(["git", "remote", "get-url", "origin"], enhancer)
    require(origin.removesuffix(".git") in ("https://github.com/zackboll/ada-gnatdoc-enhancer",
                       "git@github.com:zackboll/ada-gnatdoc-enhancer"),
            "incorrect enhancer repository")
    session.run(["git", "merge-base", "--is-ancestor", ENHANCER, "origin/main"], enhancer)
    dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
    require(dist.version == "0.1.0.dev0", "unqualified installed enhancer version")
    direct = json.loads(dist.read_text("direct_url.json"))
    require(unquote(urlsplit(direct["url"]).path) == str(enhancer)
            and not direct.get("dir_info", {}).get("editable"), "unqualified package origin")
    # Compare every installed module/asset with the immutable source, not just version text.
    for path in (enhancer / "src/ada_gnatdoc_enhancer").rglob("*"):
        if path.is_file() and "__pycache__" not in path.parts:
            installed = Path(dist.locate_file("ada_gnatdoc_enhancer")) / path.relative_to(
                enhancer / "src/ada_gnatdoc_enhancer")
            require(installed.read_bytes() == path.read_bytes(), "installed package differs from pin")
    require(importlib.metadata.version("markdown-it-py") == "3.0.0"
            and importlib.metadata.version("mdurl") == "0.1.2", "unqualified Markdown dependencies")
    session.run([sys.executable, "-m", "pip", "check"], ROOT)
    return {"revision": ENHANCER, "version": dist.version, "origin": direct,
            "installed_sha256": {p.relative_to(enhancer / "src").as_posix():
                                 digest(p.read_bytes()) for p in
                                 (enhancer / "src/ada_gnatdoc_enhancer").rglob("*")
                                 if p.is_file() and "__pycache__" not in p.parts},
            "resolved_python": session.run([sys.executable, "-m", "pip", "freeze", "--all"], ROOT)}


def native(session, source, gnatdoc, output, log_name):
    for directory in ("obj/docs", "obj/docs-internal"):
        (source / directory).mkdir(parents=True, exist_ok=True)
    text = session.run(["alr", "exec", "--", gnatdoc, "-P", "docs_api.gpr", "--backend", "html",
                        "--generate", "public", "--style", "leading", "--warnings", "-O",
                        output / "api"], source)
    require(not re.search(r"(^|\s)(error:|fatal:|ignore file due to)", text, re.I),
            "incomplete native generation")
    (session.workspace / log_name).write_text(text + "\n")


def original_gates(session, source, site, log):
    coverage = session.run([sys.executable, "scripts/check_doc_coverage.py", "--fail-on-removed",
                            "docs/gnatdoc-coverage-baseline.txt", site], source)
    require("1512/1512" in coverage and "0 newly undocumented, 0 newly documented" in coverage,
            "coverage baseline mismatch")
    warnings = session.run([sys.executable, "scripts/compare_gnatdoc_warnings.py", "--fail-on-removed",
                            "docs/gnatdoc-warning-baseline.txt", log], source)
    require("0 added, 0 removed" in warnings, "warning baseline mismatch")
    return {"coverage": coverage, "warnings": warnings}


def compare(legacy, shadow, pristine, authored):
    from ada_gnatdoc_enhancer.qualification import identities, preserve_native, bind_pristine
    from ada_gnatdoc_enhancer.syntax import TYPE_LINK
    from ada_gnatdoc_enhancer.validation import Page
    preserved = preserve_native(identities(pristine), shadow)
    bind_pristine(pristine, shadow)
    require(preserved["declarations"] == 314 and preserved["packages"] == 1,
            "native declaration baseline mismatch")
    parity = {}
    for name in ["index.html", authored["stylesheet"]["path"],
                 *(g["path"] for g in authored["guides"])]:
        require((legacy / name).read_bytes() == (shadow / name).read_bytes(),
                f"authored byte parity mismatch: {name}")
        parity[name] = {"sha256": digest((shadow / name).read_bytes()),
                        "classification": "Equivalent and verified"}
    local = external = 0
    for path in (shadow / "api").glob("*.html"):
        for link in TYPE_LINK.finditer(path.read_text()):
            if link[1].startswith("https://"):
                external += 1
                require(link[1].startswith(f"https://core.invalid/{CORE}/api/"),
                        "unapproved production type URL")
            else:
                local += 1
                dest = urlsplit(link[1])
                target = path.parent / dest.path
                require(Page(target.read_text()).ids.count(dest.fragment) == 1,
                        "invalid local type anchor")
    require((local, external) == (326, 549), "type-link baseline mismatch")
    return {"native": preserved, "local_type_links": local, "offline_external_type_links": external,
            "authored": parity, "missing_native_anchors": 0, "unexpected_native_declarations": 0,
            "presentation": "Intentional shared presentation difference; native identity preserved",
            "production_https_verified": False}


def trusted_inputs(root=ROOT):
    """Verify checked-in approval; never mint authority from current working bytes."""
    check_files(root / EVIDENCE, TRUST)
    check_files(root, {TRANSITION: TRANSITION_SHA256})
    authority = read_json(root / EVIDENCE / "authority.json")
    transition = read_json(root / TRANSITION)
    require(authority["consumer_start"] == BASE and authority["shared_enhancer"] == OLD_ENHANCER
            and authority["core"] == CORE, "authority revision mismatch")
    require(transition["consumer_main"] == BASE and transition["consumer_pr_start"] == PR_START
            and transition["consumer_pr"] == 72 and transition["old_enhancer"] == OLD_ENHANCER
            and transition["new_enhancer"] == ENHANCER and transition["core"] == CORE
            and transition["historical_records_sha256"] == TRUST
            and transition["publication"] == "shadow-only / offline-test / non-deployable",
            "unapproved enhancer authority transition")
    check_files(root, authority["files"])
    require(authority["files"][CONFIG] == transition["configuration_sha256"],
            "transition configuration mismatch")
    for key, sha in transition["unchanged_maps_sha256"].items():
        name, field = key.split(":")
        content = read_json(root / EVIDENCE / name)[field]
        require(digest(json.dumps(content, sort_keys=True, separators=(",", ":")).encode()) == sha,
                f"transition input mismatch: {key}")
    check_files(root, {transition["historical_output_record"]:
                      transition["historical_output_record_sha256"]})
    return transition


def qualify(args):
    from ada_gnatdoc_enhancer.external_types import inventory
    from ada_gnatdoc_enhancer.qualification import check_snapshot
    safe(ROOT)
    workspace = safe(args.workspace)
    require(not workspace.exists() and not workspace.is_relative_to(ROOT),
            "workspace must be new and outside the consumer checkout")
    workspace.mkdir(parents=True)
    s = Session(workspace)
    report = {"disposition": "PARTIAL_SHADOW_COMPATIBILITY", "non_deployable": True}
    try:
        require(s.run(["git", "rev-parse", "HEAD"], ROOT) == args.expected_head,
                "consumer exact head mismatch")
        s.run(["git", "merge-base", "--is-ancestor", BASE, "HEAD"], ROOT)
        # No consumer compatibility "fix" may quietly change the independent oracle.
        s.run(["git", "diff", "--exit-code", BASE, "--", "src", "cpp", "alire.toml",
               ".github/workflows/documentation.yml", "scripts/generate_docs.sh",
               "scripts/validate_docs.py", "scripts/check_doc_coverage.py",
               "scripts/compare_gnatdoc_warnings.py", "scripts/render_gnatdoc_guides.py",
               "scripts/enhance_gnatdoc_navigation.py", "scripts/install_gnatdoc_theme.py",
               "scripts/link_gnatdoc_types.py", "scripts/highlight_gnatdoc_ada.py",
               "docs_api.gpr", "docs_internal.gpr", "docs/requirements.txt",
               "docs/index.html", "docs/assets", "docs/api-categories.json", "docs/guides",
               "docs/example.adb", "docs/example.gpr", "docs/examples",
               "docs/gnatdoc-coverage-baseline.txt", "docs/gnatdoc-warning-baseline.txt"], ROOT)
        transition = trusted_inputs()
        report["authority_transition_sha256"] = TRANSITION_SHA256
        report["tool"] = provenance(s, safe(args.enhancer))
        require(s.run(["alr", "--version"], ROOT) == "alr 2.1.1", "unqualified Alire")
        legacy, source, core = (workspace / n for n in ("legacy", "source", "core"))
        # Clone exact tested head, not the mutable working tree or a reduced fixture.
        s.export(ROOT, args.expected_head, legacy)
        s.export(ROOT, args.expected_head, source)
        require(s.run(["git", "remote", "get-url", "origin"], args.core).removesuffix(".git") in
                ("https://github.com/zackboll/opencv_core_ada",
                 "git@github.com:zackboll/opencv_core_ada"), "incorrect Core acquisition repository")
        s.export(safe(args.core), CORE, core)
        consumer = read_json(ROOT / EVIDENCE / "consumer-input.json")
        authored = read_json(ROOT / EVIDENCE / "authored.json")
        core_spec = read_json(ROOT / EVIDENCE / "core-input.json")
        for snapshot in (legacy, source):
            # New integration evidence is not part of the historical production inventory.
            check_files(snapshot, consumer["source_sha256"])
            check_files(snapshot, authored["inputs"])
            require(sorted(p.relative_to(snapshot).as_posix() for p in (snapshot / "src").glob("*.ads"))
                    == consumer["public_sources"], "unexpected public source specification")
        s.run(["alr", "-n", "build"], core)
        s.run(["alr", "-n", "build"], source)
        report["resolved_core"] = dependency(source / "alire/alire.lock")
        resolved = Path(s.run(["alr", "exec", "--", "printenv", "OPENCV_CORE_ALIRE_PREFIX"], source))
        # The lock alone is not a claim that the cache contains those source bytes.
        check_files(resolved, {n: h for n, h in core_spec["source_sha256"].items()
                               if n.startswith("src/")})
        report["resolved_core_source"] = str(resolved)
        report["compiler"] = s.run(["alr", "exec", "--", "gnat", "--version"], source)
        report["gprbuild"] = s.run(["alr", "exec", "--", "gprbuild", "--version"], source)
        require(report["compiler"].splitlines()[0] == "GNAT 16.1.0", "unqualified compiler")
        require(report["gprbuild"].startswith("GPRBUILD 26.0.0 (2026-04-15)"), "unqualified GPRbuild")
        s.run(["alr", "-n", "install", f"--prefix={workspace / 'gnatdoc'}", "gnatdoc_bin=26.0.0"], source)
        gnatdoc = workspace / "gnatdoc/bin/gnatdoc"
        require(s.run([gnatdoc, "--version"], source, accepted=(0, 1)) == GNATDOC,
                "unqualified GNATdoc")
        report["gnatdoc"] = {"version": GNATDOC, "binary_sha256": digest(gnatdoc.read_bytes())}
        # The unchanged oracle runs first and is never the shared tool's input.
        s.run(["sh", "scripts/generate_docs.sh"], legacy)
        legacy_first = hashes(legacy / "_site")
        s.run(["sh", "scripts/generate_docs.sh"], legacy)
        require(hashes(legacy / "_site") == legacy_first, "legacy fresh regeneration differs")
        for script in ("install_gnatdoc_theme.py", "link_gnatdoc_types.py", "highlight_gnatdoc_ada.py",
                       "enhance_gnatdoc_navigation.py"):
            s.run([sys.executable, "scripts/" + script, legacy / "_site/api"], legacy)
        s.run([sys.executable, "scripts/render_gnatdoc_guides.py", legacy / "_site"], legacy)
        require(hashes(legacy / "_site") == legacy_first, "legacy re-enhancement differs")
        report["legacy_deterministic"] = report["legacy_byte_idempotent"] = True
        report["legacy_core"] = dependency(legacy / "alire/alire.lock")
        s.run([sys.executable, "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py", "-v"], legacy)
        report["legacy_validator"] = s.run([sys.executable, "scripts/validate_docs.py", legacy / "_site"], legacy)
        report["legacy_gates"] = original_gates(s, legacy, legacy / "_site", legacy / "obj/docs/gnatdoc.log")
        examples = []
        for project, folder, mains in (("docs/example.gpr", "docs-example", ("example",)),
                                       ("docs/examples/examples.gpr", "docs-examples", EXAMPLES)):
            s.run(["alr", "exec", "--", "gprbuild", "-P", project], legacy)
            for main in mains:
                s.run([legacy / "obj" / folder / main], legacy)
                examples.append({"project": project, "executable": main, "build_exit": 0, "run_exit": 0})
        report["examples"] = examples
        pristine = workspace / "pristine-first"
        native(s, source, gnatdoc, pristine, "native-first.log")
        native(s, source, gnatdoc, workspace / "pristine-second", "native-second.log")
        require(hashes(pristine) == hashes(workspace / "pristine-second") == consumer["pristine_sha256"],
                "nondeterministic or unapproved pristine native bytes")
        report["native_sha256"] = hashes(pristine)
        from ada_gnatdoc_enhancer.qualification import identities
        write_json(workspace / "native-identities.json", identities(pristine))
        report["native_gates"] = original_gates(s, source, pristine, workspace / "native-first.log")
        # Export the actual Core sources before introducing the documentation-only harness.
        dep_source = workspace / "core-snapshot"
        dep_source.mkdir()
        for name in core_spec["source_sha256"]:
            target = dep_source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(core / name, target)
        check_snapshot(dep_source, core_spec["source_sha256"])
        for name, text in (("docs_api.gpr", CORE_API), ("docs_internal.gpr", CORE_INTERNAL)):
            (core / name).write_text(text)
            require(digest((core / name).read_bytes()) == core_spec["acquisition"]["harness_sha256"][name],
                    "Core acquisition harness differs from GNATDOC-005")
        native(s, core, gnatdoc, workspace / "core-native", "core-native.log")
        require(hashes(workspace / "core-native") == core_spec["pristine_sha256"], "Core native identity mismatch")
        manifest = inventory(core_spec, dep_source, workspace / "core-native")
        require(manifest == read_json(ROOT / EVIDENCE / "core-types.json"), "full Core type manifest mismatch")
        report["core_manifest_types"] = len(manifest["types"])
        outputs = []
        report["legacy_sha256"] = hashes(legacy / "_site")
        for label in ("first", "second"):
            root = workspace / label
            root.mkdir()
            for name in {*consumer["source_sha256"], *authored["inputs"], CONFIG,
                         TRANSITION, transition["historical_output_record"],
                         *(EVIDENCE + "/" + n for n in TRUST)}:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source / name, target)
            for name in consumer["public_sources"]:
                target = root / "qualification-public" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source / name, target)
            bundle = root / "qualification-dependencies/core-0.4.1"
            bundle.mkdir(parents=True)
            shutil.copytree(dep_source, bundle / "source")
            shutil.copytree(workspace / "core-native", bundle / "native")
            shutil.copyfile(root / CONFIG, root / "qualification.toml")
            site = root / "_site"
            shutil.copytree(pristine, site)
            cli = [str(Path(sys.executable).parent / "gnatdoc-enhancer")]
            options = ["--source-root", root, "--config", "qualification.toml", "--site", site]
            s.run(cli + ["inventory"] + options, root)
            before = hashes(site)
            s.run(cli + ["enhance", "--dry-run"] + options, root)
            require(hashes(site) == before, "dry-run modified inputs")
            s.run(cli + ["enhance"] + options, root)
            publication = json.loads(s.run(cli + ["verify"] + options, root))
            state = hashes(site)
            historical = read_json(ROOT / transition["historical_output_record"])["shadow_sha256"]
            require(set(state) == set(historical), "published file inventory changed")
            changed = sorted(n for n in state if state[n] != historical[n])
            require(set(changed) == set(transition["approved_changed_publications"]),
                    f"unapproved published differences: {changed}")
            report["published_changes"] = {n: {"old_sha256": historical[n],
                "new_sha256": state[n], "approval": transition["approved_changed_publications"][n]}
                for n in changed}
            s.run(cli + ["enhance"] + options, root)
            require(hashes(site) == state, "enhancement is not byte-idempotent")
            outputs.append(state)
            report["comparison"] = compare(legacy / "_site", site, pristine, authored)
            # Persist structural evidence even if a later consumer gate rejects the presentation.
            report["shadow_sha256"] = state
            report["publication"] = publication
            write_json(workspace / "qualification.json", report)
            report["shadow_gates"] = original_gates(s, source, site, workspace / "native-first.log")
        require(outputs[0] == outputs[1], "independent output regeneration is nondeterministic")
        report.update({"consumer_start": BASE, "pr_start": PR_START, "consumer_tested": args.expected_head,
                       "deterministic": True, "byte_idempotent": True,
                       "legacy_sha256": hashes(legacy / "_site"), "shadow_sha256": outputs[0],
                       "disposition": "HOSTED_CI_PENDING"})
    except Exception as exc:
        report["failure"] = {"type": type(exc).__name__, "reason": str(exc)}
        raise
    finally:
        report["logs_sha256"] = {p.name: digest(p.read_bytes()) for p in workspace.glob("*.log")}
        write_json(workspace / "qualification.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--enhancer", required=True, type=Path)
    parser.add_argument("--core", required=True, type=Path)
    parser.add_argument("--expected-head", required=True)
    args = parser.parse_args()
    try:
        qualify(args)
    except (ValueError, OSError, KeyError) as exc:
        print(f"shadow qualification failed: {exc}", file=sys.stderr)
        return 1
    print(f"Non-deployable shadow evidence: {args.workspace / 'qualification.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())