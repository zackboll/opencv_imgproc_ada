#!/usr/bin/env python3
"""Independent current-source release preflight; never promotes production.

The source-side legacy matcher supplies genuine destinations and overload
ordinals. Counts are established from the selected specification and compared
to its immutable main identity, not learned from output. All sites and reports
are deliberately outside the publication tree. No historical authority changes.
"""
from __future__ import annotations

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import shutil
import subprocess

from enhance_gnatdoc_navigation import entries
from install_released_gnatdoc import checked_tool, digest, require
from link_gnatdoc_types import Source

ROOT = Path(__file__).resolve().parents[1]
BASE = "496d5d074c9bc987f625d484deb45bcdad174aa0"


def hashes(root):
    require(not any(p.is_symlink() for p in root.rglob("*")), "symlink input")
    return {p.relative_to(root).as_posix(): digest(p.read_bytes())
            for p in sorted(root.rglob("*")) if p.is_file()}


def write(path, record):
    path.write_text(json.dumps(record, sort_keys=True, indent=2) + "\n")


class Operations(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.category = None
        self.current = None
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "section" and "operation-group" in attrs.get("class", "").split():
            self.category = attrs["data-category"]
        if tag == "a" and self.category is not None:
            self.current = {"category": self.category, "href": attrs["href"], "label": ""}

    def handle_data(self, text):
        if self.current is not None:
            self.current["label"] += text

    def handle_endtag(self, tag):
        if tag == "a" and self.current is not None:
            self.links.append(self.current)
            self.current = None
        if tag == "section":
            self.category = None


def expected_operations(api):
    _, groups = entries(api, ROOT / "src", ROOT / "docs/api-categories.json")
    expected = []
    source_native = []
    for category, _, group in groups:
        for item in group:
            label = item["name"] + (f" ({item['overload']})" if item["overload"] else "")
            expected.append({"category": category, "href": item["href"], "label": label})
            source_native.append(item)
    return expected, source_native


def qualify(environment, workspace):
    tool, installed = checked_tool(environment)
    write(workspace / "installed-distribution.json", installed)
    native = workspace / "native-first"
    require(hashes(native) == hashes(workspace / "native-second"), "native nondeterminism")
    for name in ("src/opencv-image_processing.ads", "docs/api-categories.json"):
        original = subprocess.run(["git", "show", BASE + ":" + name], cwd=ROOT,
                                  check=True, capture_output=True).stdout
        require((ROOT / name).read_bytes() == original, "unreviewed source authority change")
    declarations = Source(ROOT / "src").top
    require(len(declarations) == 329, "selected source does not match current reviewed API")
    expected, inventory = expected_operations(native / "api")
    require(len(expected) == len(declarations) and
            len({x["href"] for x in expected}) == len(expected), "source/native mismatch")
    write(workspace / "source-native-inventory.json", {
        "source_authority_commit": BASE,
        "tested_commit": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                         check=True, capture_output=True, text=True).stdout.strip(),
        "source_sha256": digest((ROOT / "src/opencv-image_processing.ads").read_bytes()),
        "declarations": declarations, "operations": inventory,
        "native_sha256": hashes(native), "native_repeat_equal": True})
    source = workspace / "current-source"
    source.mkdir()
    (source / "qualification-public").mkdir()
    shutil.copyfile(ROOT / "src/opencv-image_processing.ads",
                    source / "qualification-public/opencv-image_processing.ads")
    shutil.copyfile(ROOT / "docs/api-categories.json", source / "categories.json")
    config = '''schema_version = 1
project = "opencv_imgproc_ada"
[gnatdoc]
version = "26.0.0"
[sources]
directories = ["qualification-public"]
packages = ["OpenCV.Image_Processing"]
comment_style = "leading"
[navigation]
mode = "operations"
categories = "categories.json"
[presentation]
theme = true
syntax_highlighting = true
type_links = true
'''
    (source / "qualification.toml").write_text(config)
    commands = []

    def execute(command, site, check=True):
        checked_tool(environment)
        args = [str(tool), command, "--source-root", str(source), "--config",
                "qualification.toml", "--site", str(site)]
        result = subprocess.run(args, capture_output=True, text=True)
        record = {"command": args, "returncode": result.returncode,
                  "stdout": result.stdout, "stderr": result.stderr}
        commands.append(record)
        write(workspace / "release-commands.json", commands)
        if check:
            require(result.returncode == 0, f"released {command} rejected current input: {result.stderr}")
        return record

    execute("inventory", native)
    first, second = workspace / "shared-first", workspace / "shared-second"
    shutil.copytree(native, first)
    execute("enhance", first)
    execute("verify", first)
    actual = Operations((first / "api/index.html").read_text()).links
    write(workspace / "navigation-comparison.json", {
        "expected": expected, "actual": actual, "equal": actual == expected,
        "oracle": "unchanged consumer source-profile matcher and per-name source-order ordinal",
        "historical_66_label_regression": "exact ordered category, label and destination comparison"})
    require(actual == expected, "released operation navigation differs from current source oracle")
    before = hashes(first)
    execute("enhance", first)
    require(hashes(first) == before, "repeat enhancement not byte-idempotent")
    shutil.copytree(workspace / "native-second", second)
    execute("enhance", second)
    require(hashes(second) == before, "fresh enhancements differ")
    # Rejected mutations must never be performed concurrently with browsers.
    index = first / "api/index.html"
    original = index.read_bytes()
    mutated = original.replace(expected[0]["href"].encode(), expected[1]["href"].encode(), 1)
    require(mutated != original, "destination mutation did not execute")
    try:
        index.write_bytes(mutated)
        rejected = execute("verify", first, check=False)
        require(rejected["returncode"] != 0, "wrong destination accepted")
    finally:
        index.write_bytes(original)
    # The release's explicit external-type mode cannot encode the retained
    # production package-query contract. Capture the genuine CLI rejection.
    production = config + '''[security]
external_hosts = ["zackboll.github.io"]
[external_types]
"OpenCV.Core.Mat" = "https://zackboll.github.io/opencv_core_ada/api/index.html?package=OpenCV.Core"
'''
    (source / "qualification.toml").write_text(production)
    rejected = execute("inventory", native, check=False)
    require(rejected["returncode"] != 0, "production bookmark capability unexpectedly changed")
    write(workspace / "preflight.json", {
        "disposition": "CORRECTIVE_WORK_REQUIRED", "production_changed": False,
        "source_packages": 1, "source_declarations": len(declarations),
        "ordered_navigation_pass": True, "byte_idempotent": True, "fresh_enhancements_equal": True,
        "candidate_scope": "local API presentation only; Core links absent, never publish",
        "external_bookmark_rejection": rejected,
        "core_manifest_mode": "release external_types.resolve permits offline-test .invalid only",
        "upstream_defect_confirmed": False,
        "remaining_decision": "Independently qualify explicit symbol destinations or a stable package fallback; query rejection alone does not prove a release defect or Core hosting failure",
        "not_qualified": ["production Core link replacement", "production browser/security matrix",
                          "Pages artifact", "production migration"]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--venv", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    args = parser.parse_args()
    qualify(args.venv.absolute(), args.workspace.absolute())
    # A successful local-only experiment is not a successful adoption gate.
    raise SystemExit(2)


if __name__ == "__main__":
    main()