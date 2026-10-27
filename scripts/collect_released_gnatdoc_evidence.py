#!/usr/bin/env python3
"""Collect GNATDOC-009 observations; these reports never authorize publication.

No historical authority is read as a current-source acceptance baseline. Output
inventories are evidence only. A deliberately partial probe cannot become ready
because this collector completed successfully.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import shutil
import subprocess

from check_doc_coverage import check_site
from install_released_gnatdoc import checked_tool, digest, require
from link_gnatdoc_types import SECTION, Source, visible_declarations
from qualify_released_gnatdoc import hashes, write

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--core", required=True, type=Path)
    parser.add_argument("--venv", required=True, type=Path)
    args = parser.parse_args()
    workspace = args.workspace.absolute()
    destination = ROOT / "docs/evidence/gnatdoc009"
    destination.mkdir(parents=True, exist_ok=True)
    checked_tool(args.venv.absolute())
    reports = ("preflight.json", "release-commands.json", "installed-distribution.json",
               "source-native-inventory.json", "navigation-comparison.json")
    for name in reports:
        shutil.copyfile(workspace / "final-preflight" / name, destination / name)
    for name in ("core-live-browser.json", "pr80-reconciled.json", "core-artifacts.json",
                 "pr80-paths.txt", "release-security-tests.log", "reconciled-tests.log",
                 "legacy-browser.log", "reconciled-browser.log", "compiled-examples.log",
                 "reconciled-compiled-examples.log", "reconciled-generation.log",
                 "initial-generation.log", "clean-first-native.log", "clean-second-native.log"):
        shutil.copyfile(workspace / name, destination / name)
    items, missing, errors = check_site(ROOT / "_site", ROOT)
    require(not missing and not errors and len(items) == 1596, "current source coverage failed")
    write(destination / "coverage.json", {"items": items, "missing": missing, "errors": errors,
                                          "documented": len(items)})
    site = ROOT / "_site"
    native = workspace / "clean-first-native"
    candidate = workspace / "final-preflight/shared-first"
    before, after = hashes(site), hashes(candidate)
    native_hashes = hashes(native)
    # Exact snippet/anchor/visible text comparison independent of enhancer verify.
    pages = {}
    for page in (native / "api").glob("*.html"):
        if page.name == "index.html":
            continue
        original = page.read_text()
        enhanced = (candidate / "api" / page.name).read_text()
        plain = lambda s: html.unescape(re.sub(r"<[^>]*>", "", s))
        a = [(m[1], m[2], plain(m[3])) for m in SECTION.finditer(original)]
        b = [(m[1], m[2], plain(m[3])) for m in SECTION.finditer(enhanced)]
        require(a == b and len(a) == 329, "native signatures or anchors changed")
        # The enhancer adds a document title. It is browser metadata, not body
        # declaration text; remove only its exact independently expected value.
        title = "<title>OpenCV.Image_Processing — opencv_imgproc_ada</title>"
        require(enhanced.count(title) == 1, "unexpected shared document title")
        require(plain(original) == plain(enhanced.replace(title, "", 1)),
                "visible native declaration text changed")
        pages[page.name] = {"sections": len(a), "anchors_signatures_visible_text_equal": True}
    comparison = {}
    for name in sorted(before.keys() | after.keys()):
        classification = "not qualified: partial site deliberately omits authored pages and Core links"
        if name in before and name in after:
            classification = ("byte-identical" if before[name] == after[name] else
                              "unapproved presentation/metadata difference; not production parity")
        elif name not in before:
            classification = "shared presentation addition; not approved for publication"
        comparison[name] = {"legacy_sha256": before.get(name), "shared_sha256": after.get(name),
                            "classification": classification}
    write(destination / "output-comparison.json", {"non_deployable": True, "files": comparison,
        "native": pages, "semantic_parity": False,
        "known_differences": ["586 API Core package links absent in partial probe",
            "350 shared local links versus 348 legacy; two constant type marks additionally linked",
            "Background_Label -> Component_Label; Default_Morphology_Border -> Morphology_Border_Value",
            "Shared local hrefs include package filename; legacy uses same-page fragment",
            "Authored output deliberately not passed through shared guide renderer"]})
    # These are observations of indexed Core native identity, not an approved
    # external manifest, and do not grant URLs or publication rights.
    browser = json.loads((workspace / "core-live-browser.json").read_text())
    package_pages = {}
    for page in (workspace / "core-native/api").glob("*.html"):
        match = re.search(r"<h1>([^<]+)</h1>", page.read_text())
        if match:
            package_pages[html.unescape(match[1]).lower()] = page
    core = {}
    for observation in browser["observations"]:
        if "identity" not in observation:
            continue
        identity = observation["identity"]
        owner, _, simple = identity.rpartition(".")
        spec = args.core / "src" / (owner.lower().replace(".", "-") + ".ads")
        package, lines, declarations = visible_declarations(spec)
        source = Source.__new__(Source)
        source.lines = lines
        source.top = [d for d in declarations if d["scope"].lower() ==
                      package + "." + d["name"].lower()]
        matches = []
        for section in SECTION.finditer(package_pages[owner.lower()].read_text()):
            if section[2].lower() == simple.lower():
                declaration = source.match(section[3])
                require(declaration["signature"].split()[0] in ("type", "subtype"), "not a Core type")
                matches.append({"anchor": section[1], "snippet": html.unescape(section[3]),
                                "source": declaration})
        require(len(matches) == 1, "Core source/native type is not unique")
        match = matches[0]
        core[identity] = match | {"source_sha256": digest(spec.read_bytes()),
            "hosted_snippet_equal": match["snippet"] == observation["snippet"],
            "observed_https": observation["direct"], "publication_approved": False}
    write(destination / "core-source-native-observations.json", {
        "crate_version": "0.5.0", "indexed_revision": "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f",
        "indexed_source": str(args.core), "types": core,
        "native_sha256": hashes(workspace / "core-native"),
        "native_warnings": (workspace / "core-native.log").read_text(),
        "hosting_capability_pass": browser["status"] == "pass",
        "version_compatible_publication_approval": False})
    shutil.copyfile(ROOT / "alire/alire.lock", destination / "alire.lock")
    historical = git("diff", "--name-only", "496d5d074c9bc987f625d484deb45bcdad174aa0", "--",
                     "docs/evidence/gnatdoc008", "docs/evidence/gnatdoc008c",
                     ".github/workflows/documentation-shared-shadow.yml",
                     "docs/shared-gnatdoc-shadow.toml", "scripts/shared_shadow_applicability.py")
    require(not historical, "historical evidence or policy changed")
    write(destination / "checkpoint.json", {
        "disposition": "CORRECTIVE_WORK_REQUIRED", "ready_for_independent_review": False,
        "starting_commit": "496d5d074c9bc987f625d484deb45bcdad174aa0",
        "starting_tree": "4745352fc3bba1c7bd10a21d0fbcef560aafe7fc",
        "reconciled_main": "3b44846687354f344d078104fe6101bfb7997534",
        "tested_checkpoint_commit": git("rev-parse", "HEAD"),
        "tested_checkpoint_tree": git("rev-parse", "HEAD^{tree}"),
        "final_head_policy": "Final commit/tree and hosted runs recorded in PR; no self-referential commit claim",
        "historical_controls_unchanged": True, "production_pipeline_changed": False,
        "pr80_overlapping_modified_paths": [],
        "clean_native_equal": native_hashes == hashes(workspace / "clean-second-native"),
        "existing_native_phase_equal": native_hashes == hashes(workspace / "native-first"),
        "baselines_empty": all(not (ROOT / "docs" / name).read_text().strip() for name in
            ("gnatdoc-warning-baseline.txt", "gnatdoc-coverage-baseline.txt")),
        "local_tests_exit": (workspace / "reconciled-tests.exit").read_text().strip(),
        "compiled_examples_exit": (workspace / "reconciled-compiled-examples.exit").read_text().strip(),
        "legacy_browser_exit": (workspace / "reconciled-browser.exit").read_text().strip(),
        "initial_browser_failure": "Port 8079 belonged to another task's Core site; retained failed log; rerun on verified task-owned port 18099 passed",
        "not_performed": ["complete shared production browser and adversarial matrix",
            "approved production Core manifest and stable fallback policy",
            "shared authored guide parity", "production Pages candidate and uploaded artifact equality",
            "live deployment acceptance (post-merge only)"]})
    write(destination / "evidence-sha256.json", {
        k: v for k, v in hashes(destination).items() if k != "evidence-sha256.json"})


if __name__ == "__main__":
    main()